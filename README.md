# resources
A module used to manage and re-use loaded resources for [Monkey](https://github.com/blitz-research/monkey)'s [Mojo](http://www.monkey-x.com/docs/html/Modules_mojo.html) and [Mojo 2](http://www.monkey-x.com/Store/mojo2.php) frameworks.

**This module is currently experimental, and may go through major refactoring until considered stable.**

This module aims to unify loading assets into memory by representing shared assets within a managed environment.
Functionality is currently provided to manage 'Sound', and 'Image' objects. In addition, a basic 'TextureCache' class is provided for manual 'Texture' object management. The Mojo2 backend handles 'Images' using arrays, representing frames.

Existing Mojo code is mostly compatible with the Mojo2 backend of this framework. However, the usual work is still required to port from Mojo to Mojo 2. This just makes things easier, allowing you to use this framework across projects requiring Mojo or Mojo2.

This module started as a completely different module which further wrapped the functionality provided by Mojo. This revision focuses purely on managing what's actively in memory. The 'Image' oriented functionality can be optimized further by using the 'AtlasImageManager' class. Further "atlas" management functionality has yet to be implemented.

Compatibility with the 'mojoemulator' module may be dropped at a later date.

This module is currently a part of the officially managed modules ([found here](https://github.com/Regal-Internet-Brothers/modules)) on a trial basis. None of those modules has the right to require this module yet. Experimental functionality that optionally uses this module may be provided by those modules, but not condoned.
