# Development Environment Setup Instructions

To be able to rebuild the plugin, you will first need to install a few tools. The plugin itself is written in **JavaScript** and **ruby**, but the distribution archive `dist/ladb_toolbox.rbz` is built by a **gulp** task.

The required tools and steps for successfully building this plugin are described hereafter.

## Get **Node.js** and **npm**

Download and install [Node.js](https://nodejs.org/en/download/) - *the asynchronous event driven JavaScript runtime*. This will include [npm](https://www.npmjs.com/) - *the package manager for JavaScript*.

Read this short note about [Installing Node](https://docs.npmjs.com/getting-started/installing-node) and make sure you have the latest version of **npm**:

``` bash
      $ node -v
      v7.4.0
      $ npm -v
      4.0.5
      $ npm install npm@latest -g
      $ npm -v
      4.1.1
```

On Windows you may also have to install `gulp-cli` to be able to run **gulp** from the command line:

``` bash
     $ npm install gulp-cli -g
```

## Get The Source Code

Download the source code for this plugin from the [release page](https://github.com/lairdubois/lairdubois-toolbox-sketchup-plugin/releases) or do a `git clone`.

## Install Dependencies

Change to the `build/` directory. We have placed a `package.json` file telling **npm** which dependencies to install.

``` bash
    $ cd build
    $ npm install
```

## Compile Templates And Distribution Archive

Templates in the `src/ladb_toolbox/(less|yaml|twig)` directories are compiled by a **gulp** task. If you change any of these files, you will need to recompile the templates:

``` bash
    $ cd build
    $ gulp compile
```

If you wish to build the archive [ladb_toolbox.rbz](../dist/ladb_toolbox.rbz), then:

``` bash
    $ cd build
    $ gulp build
```

The default behaviour of the **gulp** task (without argument) is to *compile* and then *build*.