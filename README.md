# About LXSC

LXSC stands for "Lua XML StateCharts", and is pronounced _"Lexie"_. The LXSC library allows you to run [SCXML state machines](http://www.w3.org/TR/scxml/) in [Lua](http://www.lua.org/).

The [Data Model](http://www.w3.org/TR/scxml/#data-module) for interpretation is all evaluated Lua, allowing you to write conditionals and data expressions in one of the best scripting languages in the world for embedded integration.

**LXSC is currently under development.** It is not yet nearly feature complete nor properly tested.

## SCXML Compliance

LXSC aims to be _almost_ 100% compliant with the [SCXML Interpretation Algorithm](http://www.w3.org/TR/scxml/#AlgorithmforSCXMLInterpretation). However, there are a few minor variations:

* **Manual Event Processing**: Where the W3C implementation calls for the interpreter to run in a separate thread with a blocking queue feeding in the events, LXSC is designed to be frame-based. You feed events into the machine and then manually call `my_lxsc:step()` to crank the machine in the same thread. This will cause the event queues to be fully processed and the machine to run until it is stable, and then return.

* **Configuration Clearing**: The W3C algorithm calls for the state machine configuration to be cleared when the interpreter is exited. LXSC will instead leave the configuration (and data model) intact for you to inspect the final state of the machine.

* **No Delayed `<send>`**: Given the non-threaded nature of LXSC, there are no immediate plans to support the `delay` or `delayexpr` attributes for `<send>` actions. (Please file an issue if this is important to you.)

## License & Contact

LXSC is copyright ©2013 by Gavin Kistner and is licensed under the [MIT License](http://opensource.org/licenses/MIT). See the LICENSE.txt file for more details.

For bugs or feature requests please open [issues on GitHub](https://github.com/Phrogz/LXSC/issues). For other communication you can [email the author directly](mailto:!@phrogz.net?subject=LXSC).