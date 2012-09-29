
Documentation for MTCoreAudio.framework is at
MTCoreAudio.framework/Documentation/index.html.

TestMTCoreAudio is a command-line executable.  If
you do not install MTCoreAudio.framework in your
framework search path (such as in $HOME/Library/Frameworks),
you may have to set your DYLD_FRAMEWORK_PATH to
include the path where MTCoreAudio.framework is located,
or to "." to run it directly from this disk image.
Note that setting your DYLD_FRAMEWORK_PATH (or any
path) to include "." is a security risk.  :)

AudioMonitor is a more sophisticated example program
demonstrating the use of MTCoreAudio.framework in
a graphical Cocoa application.

Before building TestMTCoreAudio or AudioMonitor,
you will probably have to modify the location
of MTCoreAudio.framework in the project settings
for those projects to be whatever location
MTCoreAudio.framework ends up in.

The framework is copied into AudioMonitor's
application bundle, so it won't need to be installed
in your framework search path to use the application.

Enjoy!

-mike thornburgh, 2002-11-03

