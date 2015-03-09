# resources
A module used to manage and re-use loaded resources for [Monkey](https://github.com/blitz-research/monkey)'s official game framework, [Mojo](http://www.monkey-x.com/docs/html/Modules_mojo.html).

**This module is currently experimental, and may go through major refactoring until considered stable.**

This module aims to unify loading assets into memory by representing shared assets within a managed environment.
Functionality is currently provided to manage 'Sound' and 'Image' objects.

This module started as a completely different setup which further wrapped the functionality provided by Mojo.
This revision focuses purely on managing what's actively in memory. The 'Image' oriented functionality can be optimized further by using the 'AtlasImageManager' class. Further "atlas" management functionality has yet to be implemented.

This module is not currently a part of the officially managed modules [found here](https://github.com/Regal-Internet-Brothers/modules). None of those modules has the right to require this module yet. Experimental functionality that optionally uses this module may be provided by those modules, but not condoned.
