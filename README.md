##F-Script

F-Script is a set of open source tools for dynamic introspection, manipulation and scripting of Cocoa objects on Mac OS X.


##Build

There are 3 schemes that builds the F-Script app and framework for 3 deployment targets:

- 10.7
- 10.8
- 10.9

Each target is differrent in that it links against only those frameworks that are available on the target platform.

E.g. 10.7 build will run on 10.9, but will miss many frameworks like AVFoundations. In other hand, the 10.9 build will have that framework but will not run on 10.7.


##Paid Support

If functional you need is missing but you're ready to pay for it, feel free to contact me. If not, create an issue anyway, I'll take a look as soon as I can.
