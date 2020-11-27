Required software
=================

-   [Haskell GHC compiler and Cabal build
    tool](https://www.haskell.org/downloads/#minimal)

Optional software
=================

-   [Pandoc](https://pandoc.org/): by default this will be built from
    source using GHC, but this can take a very long time and make your
    computer work really hard. To avoid that, you can optionally install
    it using your operating system\'s package manager.

Instructions to build the website
=================================

After building, the website will be available in generated html files in
`./public_html`, and you can then copy this directory over to your
webserver to make it publicly available.

Some of these instructions are a little technical, but it is very
important to us that the materials are accessible, so if you would like
to build the website please don\'t hesitate to reach out to Adam
(akm2203 \"at\" columbia \"dot\" edu). Adam is happy to walk through the
process and debug any problems with you. You are also doing us a favor
by reaching out, as it will help us improve the build instructions and
fix bugs.

General instructions
--------------------

Clone this repository with `git clone --recursive`, enter the directory,
and run:

``` {.bash}
cabal run build
```

This will build the website according to default options. However, there
are also a couple of options that will customize the website and build
processes:

### Customize the website with your own links, names, and dates

You can provide your own configuration file that will customize the
generated web content using your own information. See the file
`abby-adam.config` for an example; you can copy that file and edit it to
your needs.

To specify the configuration file run:

``` {.bash}
cabal run build -- --config=abby-adam.config
```

,

replacing `abby-adam.config` with the path to your configuration file.

### Use your installed version of Pandoc instead of building from source

By default the build system will build `pandoc` from source, which can
take a very long time. To avoid that, you can tell the build system to
use your own installed version of Pandoc, if it is available for your
OS. This can be done with the option `--pandoc`:

``` {.bash}
cabal run build -- --pandoc=/path/to/pandoc
```

,

replacing `/path/to/pandoc` with the path to your OS-installed version
of Pandoc (e.g., `/bin/pandoc` on Linux).

Contributing content
====================

All content is generated from files in `/website-src`. Edit or add files
there to update website content. The build system will automatically
generate a new website if you execute the command `cabal run build`.

Our goal is to collaboratively and iteratively improve the workshop, so
contributions are enthusiastically encouraged. One way to edit files is
to use [Github\'s cloud editing
feature](https://docs.github.com/en/free-pro-team@latest/github/managing-files-in-a-repository/editing-files-in-another-users-repository),
but even this option can be a little technical. If you are having any
issues or have any questions, please do not hesitate to reach out to
Adam (akm2203 \"at\" columbia \"dot\" edu).

Modifying the build system
==========================

The build system is based on [Shake](https://shakebuild.com/), and can
be modified with the `Shakefile.hs` file.

Licenses
========

All written content (`./public_html` and `./website_src`) is provided
under a [CC BY license](http://creativecommons.org/licenses/by/4.0/):

<a rel="license"
href="http://creativecommons.org/licenses/by/4.0/"><img alt="Creative
Commons License" style="border-width:0"
src="https://i.creativecommons.org/l/by/4.0/88x31.png" /></a><br
/>All written content on this website is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/4.0/">Creative Commons
Attribution 4.0 International License</a>

All code (`Shakefile.hs`) is provided under either a BSD 3-clause
license or the Apache 2.0 License, at the user\'s discretion. See
`LICENSE.org`.
