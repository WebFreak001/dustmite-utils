# dustmite-utils

Utilities to interactively improve dustmite's reduction times on D projects.

Current helpers:
- `dustmite-utils clear-unittests [SOURCES...]` clears all `unittest {}` blocks to be empty in selected files
	- especially when compiling with unittests this can help eliminate a lot of unneeded code more quickly
- `dustmite-utils remove-comments [SOURCES...]` removes all comments
	- just saves on I/O overhead

Building:

```
dub build
```

Usage:

1. Make a copy of your dustmite test folder / what dustmite already reduced
2. run desired helper on test folder
3. make sure dustmite test still applies, otherwise revert and optionally try again with smaller subset of files

## Future ideas

- resolve package.d files that only contain imports
	- `import std;` -> `import std.a; import std.b; ... import std.z;`
		- selective imports need to be checked with a bunch of `__traits(compiles)` (needs access to compiler options)
		- need to delete the package.d files, so that they won't accidentally be reduced again, or add them to the reject list
- refactor single imports / copy-paste content into file
- interactive UI / vscode integration for running things on-demand
	- start dustmite session UI:
		```
		Run Script: [ file.sh          ]
		[x] Check for exit code       [ SEGFAULT    ]
		[x] Check for compiler output [ ^$          ]

		Pre-processing:
		[x] Remove comments
		[x] Clear unittests

		Advanced optimizations:
		    Build flags: [ dmd -c -I. %s     ]
		[x] Resolve import-only package.d

		Dustmite Scope:
		[x] DUB dependencies
		[x] phobos
		[ ] druntime

		Dustmite Options:
		[x] Reject `import std;` minimization
		[x] Use multi-core processing on [ 16   ] cores
		[x] Put files in RAM to increase RAM usage but significantly decrease disk I/O usage and improve speed.
		```
	- auto-detect when (all) imports to certain modules have been removed, offer the option to start a new dustmite iteration when this happens
		- since dustmite at the start of an iteration tries larger removals, such as deleting entire files, it will try deleting modules again that previously were only kept due to dead imports
	- show live lines-of-code graph + code tree that shows remaining files and folders
	- interactive manual removal of code in editor (when applied, stops dustmite, applies diff to reduced output, restarts dustmite on the replaced reduced output)
	- be able to checkpoint, to later test and revert to checkpoints with modified test script
	- clean up imports inside files
		- merge all imports into global imports, so they can be often checked for removal at the start
		- for selective imports, when removal is attempted, remove entire import
	- auto-remove all references to 0-size modules
