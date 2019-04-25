# Development Environment Setup Instructions

To be able to rebuild the plugin, you will first need to install a few tools. The plugin itself is written in **JavaScript** and **ruby**, but the distribution archive `dist/ladb_toolbox.rbz` is built by a **gulp** task.

The required tools and steps for successfully building this plugin are described hereafter.

## 1. Get **Node.js** and **npm**

Download and install [Node.js](https://nodejs.org/en/download/) - *the asynchronous event driven JavaScript runtime*. This will include [npm](https://www.npmjs.com/) - *the package manager for JavaScript*.

Read this short note about [Installing Node](https://docs.npmjs.com/getting-started/installing-node) and make sure you have the latest version of **npm**:

``` bash
    $ node -v
    v10.15.3
    $ npm -v
    6.4.1
    $ npm install npm@latest -g
    $ npm -v
    6.8.0
```

On Windows you may also have to install `gulp-cli` to be able to run **gulp** from the command line:

``` bash
     $ npm install gulp-cli -g
```

## 2. Get The Source Code

The best way to get project sources is to clone them from GitHub repository. For that you need to have [Git](https://git-scm.com/) installed on your computer.
It's better because in this way you will be able to retrive future updates of the origin sources.

Move to your project parent folder. Adapt it to your needs and environment.

``` bash
     $ cd /somewhere/on/your/computer
```

And clone the project from sources.

``` bash
     $ git clone git@github.com:lairdubois/lairdubois-opencutlist-sketchup-extension.git 
```

Change to project directory :

``` bash
     $ cd lairdubois-opencutlist-sketchup-extension
```

In the future, if you want to retrieve origin sources updates, just execute the git pull command from your project directory.
Caution that if you change some files it cans generate some code conflicts that you need to solve.

``` bash
     $ git pull origin master
```

## 3. Install Dependencies

From the project directory, change to the `build/` directory. We have placed a `package.json` file telling **npm** which dependencies to install.

``` bash
    $ cd build
    $ npm install
```

## 4. Compile Templates And Distribution Archive

Templates in the `src/ladb_opencutlist/(less|yaml|twig)` directories are compiled by a **gulp** task. If you change any of these files, you will need to recompile the templates:

``` bash
    $ cd build
    $ gulp compile
```

If you wish to build the archive [ladb_opencutlist.rbz](../dist/ladb_opencutlist.rbz), then:

``` bash
    $ cd build
    $ gulp build
```

If you wish to build the archive [ladb_opencutlist-dev.rbz](../dist/ladb_opencutlist-dev.rbz), then:

``` bash
    $ cd build
    $ gulp build --env=dev
```

The default behaviour of the **gulp** task (without argument) is to *compile* and then *build*.


## 5. Adding a new language

Adding new languages is quit simple. You just need to add a new `.yml` file in `src/yaml/i18n` directory by duplicating `fr.yml` and changing all key values into the desired language.
It's important to keep and change the first key `_label` to the corresponding readable label or the new language.

After you need to compile the projet (see 4.) and your new language will appear in the **Preferences panel** of the *OpenCutList*.