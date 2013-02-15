# About LXSC

LXSC stands for "Lua XML StateCharts", and is pronounced _"Lexie"_. The LXSC library allows you to run [SCXML state machines][1] in [Lua][2].

The [Data Model][3] for interpretation is all evaluated Lua, allowing you to write conditionals and data expressions in one of the best scripting languages in the world for embedded integration.

LXSC is not yet released, but it is getting close. (It currently passes every self-running test case in the ['test/testcases' directory][4].)

## SCXML Compliance

LXSC aims to be _almost_ 100% compliant with the [SCXML Interpretation Algorithm][5]. However, there are a few minor variations (compared to the Working Draft as of 2013-Feb-14):

* **Manual Event Processing**: Where the W3C implementation calls for the interpreter to run in a separate thread with a blocking queue feeding in the events, LXSC is designed to be frame-based. You feed events into the machine and then manually call `my_lxsc:step()` to crank the machine in the same thread. This will cause the event queues to be fully processed and the machine to run until it is stable, and then return.

* **Configuration Clearing**: The W3C algorithm calls for the state machine configuration to be cleared when the interpreter is exited. LXSC will instead leave the configuration (and data model) intact for you to inspect the final state of the machine.

* **No Delayed `<send>`**: Given the non-threaded nature of LXSC, there are no immediate plans to support the `delay` or `delayexpr` attributes for `<send>` actions. (Please file an issue if this is important to you.)

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
