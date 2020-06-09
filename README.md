# UnoDOS III 3.1 Wolf

The alternative operating system for divMMC. Finely tuned.

## Build prerequisites

The preferred IDE is _Visual Studio Code_ (https://code.visualstudio.com/) with Imanolea's _Z80 Assembly_ extension (install from the app).

The compiler is the _Zeus Command Line_ assembler.

### Linux

* Install _Wine_: `sudo apt-get install wine`

### macOS (Mojave and earlier)

1. Install _HomeBrew_ (https://brew.sh/):

   `/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`

2. After _HomeBrew_ is installed, install _Wine_:

   `brew install wine`

### Windows

No additional prerequisites.

## Components

The OS comprises:

* __KERNEL__: The interface between the divMMC hardware and the host machine.
* __COMMANDS__: Small programs that provide shell functions when using UnoDOS III without SE Basic IV. 
* __KEXTS__: Third-party kernel extensions that provide additional functionality.

## License

Copyright &copy; 2017-2020 Source Solutions, Inc. All rights reserved.

Licensed under the [GNU General Public License](LICENSE).
