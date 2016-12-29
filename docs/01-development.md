Development environement setup instructions
===========================================

To be able to rebuild the plugin *.rbz* archive, you need to install some tools.

The plugin *.rbz* archive is build by a **Glup** task. Then first, you need to install **Glup** and some dependencies.

## 1. Install [Node.js](https://nodejs.org/en/download/) and [npm](https://www.npmjs.com/) - *The package manager for JavaScript*

The way to do this depend of your OS. See the [Doc](https://docs.npmjs.com/getting-started/installing-node)

## 2. Install dependencies

``` bash
    $ cd build
    $ npm install
```

## 3. Run tasks !

Now you are ready to run tasks.

If you only want to compile less, yaml and twig :

``` bash
    $ cd build
    $ gulp compile
```

If you want to build the .rbz archive

``` bash
    $ cd build
    $ gulp build
```

