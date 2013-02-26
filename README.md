# About LXSC

LXSC stands for "Lua XML StateCharts", and is pronounced _"Lexie"_. The LXSC library allows you to run [SCXML state machines][1] in [Lua][2]. The [Data Model][3] for interpretation is all evaluated Lua, allowing you to write conditionals and data expressions in one of the best scripting languages in the world for embedded integration.

# Table of Contents

* [Usage](#usage)
  * [The Basics](#the-basics)
  * [Customizing the Data Model](#customizing-the-data-model)
  * [Callbacks as the Machine Changes](#callbacks-as-the-machine-changes)
    * [State Change Callbacks](#state-change-callbacks)
    * [Data Model Callback](#data-model-callback)
    * [Transition Callback](#transition-callback)
  * [Peeking and Poking at the Data Model](#peeking-and-poking-at-the-data-model)
  * [Examining the State of the Machine](#examining-the-state-of-the-machine)
* [Custom Executable Content](#custom-executable-content)
* [SCXML Compliance](#scxml-compliance)
* [TODO (aka Known Limitations)](#todo-aka-known-limitations)
* [License & Contact](#license--contact)

## Usage

### The Basics

    require"lxsc-min-0.8"                    -- or dofile"lxsc-bin-0.8.luac"

    local scxml   = io.read('my.scxml'):read('*all')
    local machine = LXSC:parse(scxml)
    machine:start()                          -- initiate the interpreter and run until stable

    machine:fireEvent("my.event")            -- add events to the event queue to be processed
    machine:fireEvent("another.event.name")  -- as many as you like; they won't have any effect until you
    machine:step()                           -- call step() to process all events and run until stable

    print("Is the machine still running?",machine.running)
    print("Is a state in the configuration?",machine:isActive('some-state-id'))

    -- Keep firing events and calling step() to process them

### Customizing the Data Model

The data model used by the interpreter is a Lua table. This table is used to store and retrieve the values created via [`<data>`](http://www.w3.org/TR/scxml/#data) or [`<assign>`](http://www.w3.org/TR/scxml/#assign). This table is also used as the environment under which the [`<script>`](http://www.w3.org/TR/scxml/#script) blocks run and the `code="…"` attributes of [`<transition>`](http://www.w3.org/TR/scxml/#transition) elements are evaluated.

Providing your own data model table allows you to:

* supply an initial set of data values—useful for initial conditional transitions
* expose functions, either utilities like `print()` or custom defined functions that provide the meat for a simple `<script>doTheThing()</script>` semantic callbacks
* create a custom datatable that performs metamagic when new keys are accessed or modified by the state machine

You supply a custom data model table by passing a named `data` parameter to the `start()` method:

    local mydata = { reloading=true, userName="Gavin"   } -- populate initial data values
    local funcs  = { print=print, doTheThing=utils.doIt } -- create 'global' functions
    setmetatable( mydata, {__index=funcs} )
    machine:start{ data=mydata }

### Callbacks as the Machine Changes

There are four special machine keys that you may set to a function value to keep track of what the machine is doing: `onBeforeExit`, `onAfterEnter`, `onDataSet`, and `onTransition`.

#### State Change Callbacks

    machine.onBeforeExit = function(stateId,stateKind,isAtomic) ... end
    machine.onAfterEnter = function(stateId,stateKind,isAtomic) ... end

The state change callbacks are passed three parameters:

* The string id of the state being exited or entered.
* The string kind of the state: `"state"`, `"parallel"`, or `"final"`.
  * _The callbacks are not invoked for `history` or `initial` pseudo-states._
* A boolean indicating whether the state is atomic or not.

As implied by the names the `onBeforeExit` callback is invoked right **before** leaving a state, whilte the `onAfterEnter` callback is invoked right **after** entering a state.

#### Data Model Callback

    machine.onDataSet = function(dataid,newvalue) ... end

If supplied, this callback will be invoked any time the data model is changed.

**Warning**: using this callback may slow down the interpreter appreciably, as many internal modifications take place during normal operation (most notably setting the [`_event` system variable](http://www.w3.org/TR/scxml/#SystemVariables)).

#### Transition Callback

    machine.onTransition = function(transitionTable) ... end   

The `onTransition` callback is invoked right before the executable content of a transition (if any) is run.

**Warning**: the table supplied by this callback is an internal representation whose implementation is not guaranteed to remain unchanged. Currently you can access the following keys for information about the transition:

* `type` - the string `"internal"` or `"external"`.
* `cond` - the string value of the `cond="…"` attribute, if any, or `nil`.
* `_event` - the string value of the `event="…"` attribute, if any, or `nil`.
* `_target` - the string of the `target="…"` attribute, if any, or `nil`.
* `events` - an array of internal `LXSC.Event` tables, one for each event, or `nil`.
* `targets` - an array of internal `LXSC.State` tables, one for each target, or `nil`.
* Any custom attributes supplied on the transition appear as direct attributes (with no namespace information or protection).

### Peeking and Poking at the Data Model

While the machine is running (after you have called `start()`) you can peek at the data for a specific location via:

    local theValue = machine:get("dataId")

…and you can set the value for a particular location via:

    machine:set("dataId",someValue)

You can evaluate code in the data model (just like a `cond="…"` or `expr="…"` attribute does) by:

    local theResult = machine:eval("mycodestring")

…and you can run arbitrary code against the data model (just like a `<script>` block does) by:

    machine:run("mycodestring")

### Examining the State of the Machine

You can ask a running machine if a particular state id is active (in the current configuration):

    print("Is the foo-bar state active?", machine:isActive('foo-bar'))

…or you can ask for the set of all states that are active:

    for stateId,_ in pairs(machine:activeStateIds()) do
      print("This state is currently active:",stateId)
    end

…or you can ask just for the set of atomic (no sub-state) states:

    for stateId,_ in pairs(machine:activeAtomicIds()) do
      print("This atomic state is currently active:",stateId)
    end

You can also ask for a list of all state IDs in the machine, including those autogenerated for states that have no `id="…"` attribute:

    for stateId,_ in pairs(machine:allStateIds()) do
      print("One of the states has this id:",stateId)
    end

You can ask a machine for the set of all events that trigger transitions:

    for eventDescriptor,_ in pairs(machine:allEvents()) do
      -- eventDescriptor is a simple dotted string, e.g. "foo.bar"
      print("There's at least one transition triggered by:",eventDescriptor)
    end

…or you can ask just for the events that may trigger a transition in the current configuration:

    for eventDescriptor,_ in pairs(machine:availableEvents()) do
      print("There's at least one active transition triggered by:",eventDescriptor)
    end

## Custom Executable Content

Anywhere that [executable content](http://www.w3.org/TR/scxml/#executable) is permitted—in `<onentry>`, `<onexit>`, and `<transition>`—a state chart may specify custom elements via a custom XML namespace. For example:

    <state xmlns:my="goodstuff">
      <onentry><my:explode amount="10"/></onentry>
    </state>

With no modifications, when LXSC encounters such an executable it fires a `error.execution.unhandled` event internally with the `_event.data` set to the string `"unhandled executable type explode"`. This does not halt execution of the intepreter (unless the state machine reacts to that event in a violent manner, such as transitioning to a `<final>` state).

However, if you want such elements to actually do something, you can extend LXSC like so:

    require'lxsc-min-0.8' -- or dofilelxsc-min-0.8.luac'
    function LXSC.Exec:explode(machine)
      print("The state machine wants to explode with an amount of",self.amount)
    end

The current machine is passed to your function so that you may call `:fireEvent()`, `:eval()`, etc. as needed. Attributes on the element are set as named keys on the `self` table supplied to your function (e.g. `amount` above).

**Note**: executable elements with conflicting names in different namespaces will use the same callback function. The only way to disambiguate them currently is via a `_nsURI` property set on the table. For example, to handle this document:

    <state xmlns:my="goodstuff" xmlns:their="badstuff">
      <onentry><my:explode amount="10"/><my:explode chunkiness="very"/></onentry>
    </state>

you would need to do something like:

    function LXSC.Exec:explode(machine)
      if self._nsURI=='goodstuff' then
        print("The state machine wants to explode with an amount of",self.amount)
      else
        machine:fireEvent("error.execution.unhandled")
      end
    end

You can also use this to re-implement or augment existing executables like `<log>`:

    -- Augmenting the <log> to use a logger with a custom logging level, e.g.
    -- <transition event="error.*">
    --   <log label="An error occurred" expr="_event.data" my:log-level="error" />
    -- </transition>
    function LXSC.Exec:log(machine)
      local result = {self.label}
      if self.expr then table.insert(result,machine:eval(self.expr)) end
      local level = self['log-level'] or 'info'
      my_global_logger[level]( my_global_logger, table.concat(result,": ") )
    end


## SCXML Compliance

LXSC aims to be _almost_ 100% compliant with the [SCXML Interpretation Algorithm][5]. However, there are a couple of minor variations (compared to the Working Draft as of 2013-Feb-14):

* **Manual Event Processing**: Where the W3C implementation calls for the interpreter to run in a separate thread with a blocking queue feeding in the events, LXSC is designed to be frame-based. You feed events into the machine and then manually call `my_lxsc:step()` to crank the machine in the same thread. This will cause the event queues to be fully processed and the machine to run until it is stable, and then return. Rinse/repeat the process of event population followed by calling `step()` each frame.
  * This single-threaded, on-demand approach affects a delayed `<send>` the most. While a `<send event="e" delay="1s"/>` command will not inject the event _at least_ one second has passed, it could be substantially longer than that **if** your script only calls `step()` every 30 seconds, or (worse) waits until some user interaction occurs to call `step()` again.

* **Configuration Clearing**: The W3C algorithm calls for the state machine configuration to be cleared when the interpreter is exited. LXSC will instead leave the configuration (and data model) intact for you to inspect the final state of the machine.

## TODO (aka Known Limitations)

* The `src="…"` attribute is unsupported for `<data>` elements.
* Data model locations like `foo.bar` get and set a single key instead of nested tables.
* `<assign>` elements do not support executable content instead of `expr="…"`
* `<send>` selements do not support the `type`/`typeexpr`/`target`/`targetexpr` attributes.
* No support for executable elements `<if>`/`<elseif>`/`<else>`/`<foreach>`.
* No support for executable elements `<if>`/`<elseif>`/`<else>`/`<foreach>`.
* No support for inter-machine communication.
* No support for `<invoke>`.
* No support for `<param>` in `<donedata>`, nor has there been extensive testing of donedata.

## License & Contact

LXSC is copyright ©2013 by Gavin Kistner and is licensed under the [MIT License][6]. See the LICENSE.txt file for more details.

For bugs or feature requests please open [issues on GitHub][7]. For other communication you can [email the author directly](mailto:!@phrogz.net?subject=LXSC).

[1]: http://www.w3.org/TR/scxml/
[2]: http://www.lua.org/
[3]: http://www.w3.org/TR/scxml/#data-module
[4]: https://github.com/Phrogz/LXSC/tree/master/test/testcases
[5]: http://www.w3.org/TR/scxml/#AlgorithmforSCXMLInterpretation
[6]: http://opensource.org/licenses/MIT
[7]: https://github.com/Phrogz/LXSC/issues
