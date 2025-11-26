var gulp = require('gulp');
var del = require('del');
var minimist = require('minimist');
var fs = require('fs');
var ladb_twig_compile = require('./plugins/gulp-ladb-twig-compile');
var ladb_i18n_js_compile = require('./plugins/gulp-ladb-i18n-js-compile');
var ladb_i18n_dialog_compile = require('./plugins/gulp-ladb-i18n-dialog-compile');
var concat = require('gulp-concat');
var zip = require('gulp-zip');
var less = require('gulp-less');
var replace = require('gulp-replace');
var rename = require("gulp-rename");
var touch = require('gulp-touch-custom');
var glob = require('glob');
var yaml = require('js-yaml');
var path = require('path');
var cleanCSS = require('gulp-clean-css');
var uglify = require('gulp-uglify');
var pxtorem = require('gulp-pxtorem');
var run = require('gulp-run');

var knownOptions = {
    string: 'env',
    default: { env: process.env.NODE_ENV || 'prod' }
};

var options = minimist(process.argv.slice(2), knownOptions);
var isProd = options.env.toLowerCase() === 'prod';

// Convert less to .css files
gulp.task('less_compile', function () {
    return gulp.src('../src/ladb_opencutlist/less/ladb-opencutlist.less')
        .pipe(less())
        .pipe(gulp.dest('../src/ladb_opencutlist/css'));
});

// Minify .css files + replace px to rem
gulp.task('css_minify', function () {
    return gulp.src('../src/ladb_opencutlist/css/**/!(*.min).css')
        .pipe(cleanCSS())
        .pipe(rename({ suffix: '.min' }))
        .pipe(pxtorem({ minPixelValue: 1, propList: [
            'font', 'font-size',
                'line-height',
                'letter-spacing',
                'width', 'min-width',
                'height', 'min-height',
                'padding',// 'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
                'margin',// 'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
                'top', 'right', 'bottom', 'left',
                'border-width',
                'gap'
            ] }))
        .pipe(gulp.dest('../src/ladb_opencutlist/css'));
});

// Minify lib .js files
gulp.task('js_minify', function () {
    return gulp.src('../src/ladb_opencutlist/js/lib/**/!(*.min).js')
        .pipe(uglify())
        .pipe(rename({ suffix: '.min' }))
        .pipe(gulp.dest('../src/ladb_opencutlist/js/lib'));
});

// Convert twig runtime templates to .js precompiled files
gulp.task('twig_compile', function () {
    'use strict';

    // Clean previously generated dialog files
    del('../src/ladb_opencutlist/js/templates/*twig-templates.js', {
        force: true
    });

    gulp.src('../src/ladb_opencutlist/twig/components/**')
        .pipe(ladb_twig_compile('components/'))
        .pipe(concat('components-twig-templates.js'))
        .pipe(gulp.dest('../src/ladb_opencutlist/js/templates'));

    gulp.src('../src/ladb_opencutlist/twig/core/**')
        .pipe(ladb_twig_compile('core/'))
        .pipe(concat('core-twig-templates.js'))
        .pipe(gulp.dest('../src/ladb_opencutlist/js/templates'));

    gulp.src('../src/ladb_opencutlist/twig/modals/**')
        .pipe(ladb_twig_compile('modals/'))
        .pipe(concat('modals-twig-templates.js'))
        .pipe(gulp.dest('../src/ladb_opencutlist/js/templates'));

    return gulp.src('../src/ladb_opencutlist/twig/tabs/**')
        .pipe(ladb_twig_compile('tabs/'))
        .pipe(concat('tabs-twig-templates.js'))
        .pipe(gulp.dest('../src/ladb_opencutlist/js/templates'));
});

// Convert yaml i18n to .js files
gulp.task('i18n_compile', function () {

    const sourceLanguage = 'fr';
    const defaultLanguage = 'en';
    const yamlSrcPath = '../src/ladb_opencutlist/yaml/i18n-src/';
    const yamlDestPath = '../src/ladb_opencutlist/yaml/i18n/';

    const defaultContents = fs.readFileSync(yamlSrcPath + defaultLanguage + '.yml');
    const defaultYmlDocument = yaml.load(defaultContents);

    const languageLabels = {};
    const languageDisabledMsgs = {};
    const languageReloadMsgs = {};
    const descriptions = {};

    // Create the destination folder
    fs.mkdirSync(yamlDestPath, { recursive: true });

    // Clean previously generated i18n yml files
    del.sync(yamlDestPath + '*', { force: true });

    // Clean previously generated i18n js files
    del.sync('../src/ladb_opencutlist/js/i18n/*', { force: true });

    glob.sync(yamlSrcPath + '*.yml').forEach(function (ymlFile) {
        const contents = fs.readFileSync(ymlFile);
        const ymlDocument = yaml.load(contents);
        const language = path.basename(ymlFile, '.yml');

        // Extract shared keys
        if ('_label' in ymlDocument) {
            languageLabels[language] = ymlDocument['_label'];
        }
        if ('_description' in ymlDocument) {
            descriptions[language] = ymlDocument['_description'].replace("'", "\\'");
        }
        if ('_disabled_msg' in ymlDocument) {
            languageDisabledMsgs[language] = ymlDocument['_disabled_msg'];
        }
        if ('_reload_msg' in ymlDocument) {
            languageReloadMsgs[language] = ymlDocument['_reload_msg'];
        }

        function deleteHiddenKeys(doc) {
            for (let key in doc) {
                if (doc.hasOwnProperty(key)) {
                    if (key.startsWith('_')) {
                        delete doc[key];
                    } else if (typeof doc[key] == 'object') {
                        deleteHiddenKeys(doc[key]);
                    }
                }
            }
        }

        function fillDefaultValues(doc, defaultDoc) {
            for (let key in defaultDoc) {
                if (typeof doc[key] !== typeof defaultDoc[key] || doc[key] === '') {
                    doc[key] = defaultDoc[key]; // Fill with the entire subtree is the typeof is "object"
                } else if (typeof defaultDoc[key] === 'object') {
                    fillDefaultValues(doc[key], defaultDoc[key]);
                }
            }
        }

        const destYmlDocument = JSON.parse(JSON.stringify(ymlDocument));
        deleteHiddenKeys(destYmlDocument);
        if (language !== sourceLanguage && language !== defaultLanguage) {
            fillDefaultValues(destYmlDocument, defaultYmlDocument);
        }

        fs.writeFileSync(yamlDestPath + language + '.yml', yaml.dump(destYmlDocument, {
            lineWidth: -1,
            quotingType: '"'
        }), (err) => {
            if (err) {
                console.log(err);
            }
        });

        if (!isProd) {

            const destZzYmlDocument = JSON.parse(JSON.stringify(ymlDocument));
            let line = 0;
            const fillZZValues = function (doc) {
                for (var key in doc) {
                    if (typeof doc[key] === 'string') {
                        line++;
                        if (!doc[key].match(/^\$t\([a-z_.]+\)$/i)) {
                            doc[key] = line + ' - ' + doc[key];
                        }
                    } else if (typeof doc[key] === 'object') {
                        fillZZValues(doc[key]);
                    }
                }
            }

            fillZZValues(destZzYmlDocument);

            fs.writeFileSync(yamlDestPath + 'zz_' + language + '.yml', yaml.dump(destZzYmlDocument, {
                lineWidth: -1,
                quotingType: '"'
            }), (err) => {
                if (err) {
                    console.log(err);
                }
            });

        }

    });

    gulp.src('../src/ladb_opencutlist.rb')
        .pipe(replace(/( {6}## DESCRIPTION_START ##)(.*?\n*\t*)( {6}## DESCRIPTION_END ##)/ms, function (match, p1, p2, p3, offset, string) {
            var whens = p1;
            for (var key in descriptions) {
                if (key === defaultLanguage) {
                    continue;
                }
                whens += "\n      when '" + key + "'";
                whens += "\n        ex.description = '" + descriptions[key] + "'";
            }
            whens += "\n      else";
            whens += "\n        ex.description = '" + descriptions[defaultLanguage] + "'";
            whens += "\n" + p3;
            return whens;
        }))
        .pipe(gulp.dest('../src'))
        .pipe(touch());

    return gulp.src(yamlDestPath + (isProd ? '!(zz*)' : '*') + '.yml')
        .pipe(ladb_i18n_js_compile(languageLabels, languageDisabledMsgs, languageReloadMsgs))
        .pipe(gulp.dest('../src/ladb_opencutlist/js/i18n'));
});

// Compile dialog.twig to dialog-XX.html files - this permits to avoid dynamic loading on runtime
gulp.task('i18n_dialogs_compile', function () {

    // Clean previously generated dialog files
    del.sync('../src/ladb_opencutlist/html/dialog-*', {
        force: true
    });

    gulp.src('../src/ladb_opencutlist/yaml/i18n/' + (isProd ? '!(zz*)' : '*') + '.yml')
        .pipe(ladb_i18n_dialog_compile('../src/ladb_opencutlist/twig/dialog-modal.twig', 'modal'))
        .pipe(gulp.dest('../src/ladb_opencutlist/html'));

    return gulp.src('../src/ladb_opencutlist/yaml/i18n/' + (isProd ? '!(zz*)' : '*') + '.yml')
        .pipe(ladb_i18n_dialog_compile('../src/ladb_opencutlist/twig/dialog-tabs.twig', 'tabs'))
        .pipe(gulp.dest('../src/ladb_opencutlist/html'));
});

// Create the .rbz archive
gulp.task('rbz_create', function () {
    var blob = [
        'src/**/!(.DS_store|*.less|*.twig|!(*.min).css)',
        '!src/**/less/**',
        '!src/**/twig/**',
        '!src/**/cpp/**',
        '!src/**/bin/**/!(*.dylib|*.dll)',
        '!src/**/yaml/i18n-src/**',
    ];
    // Exclude not minified .js libs
    blob.push('!src/**/js/lib/!(*.min).js');
    if (isProd) {
        // Exclude zz debug languages in prod environment
        blob.push('!src/**/yaml/i18n/zz*.yml');
    }
    return gulp.src(blob, { cwd: '../'})
        .pipe(zip('ladb_opencutlist.rbz'))
        .pipe(gulp.dest('../dist'));
});

// Version
gulp.task('version', function () {

    // --no-manifest        # default = --manifest=true

    // Retrive version from package.json
    var pkg = JSON.parse(fs.readFileSync('./package.json'));
    var version = pkg.version + (isProd ? '' : '-' + options.env.toLowerCase());

    // Compute build from the current date
    var nowISO = (new Date()).toISOString();
    var build = nowISO.slice(0,10).replace(/-/g, "") + nowISO.slice(11,16).replace(/:/g, "");

    if (options.manifest || options.manifest === undefined) {
        // Update version property in manifest.json
        gulp.src('../dist/manifest.json')
            .pipe(replace(/"version": "[0-9.]+(-[a-z]*)?"/g, '"version": "' + version + '"'))
            .pipe(replace(/"build": "[0-9]{12}?"/g, '"build": "' + build + '"'))
            .pipe(replace(/"url": "[a-z:\/.\-]+"/g, '"url": "https://www.lairdubois.fr/opencutlist/download' + (isProd ? '' : '-' + options.env.toLowerCase()) + '"'))
            .pipe(gulp.dest('../dist'))
            .pipe(touch());
    }

    // Update version property in ladb_opencutlist.rb
    gulp.src('../src/ladb_opencutlist.rb')
        .pipe(replace(/ex.version     = "[0-9.]+(-[a-z]*)?"/g, 'ex.version     = "' + version + '"'))
        .pipe(gulp.dest('../src'))
        .pipe(touch());

    // Update version property in constants.rb
    gulp.src('../src/ladb_opencutlist/ruby/constants.rb')
        .pipe(replace(/EXTENSION_VERSION = '[0-9.]+(-[a-z]*)?'/g, "EXTENSION_VERSION = '" + version + "'"))
        .pipe(replace(/EXTENSION_BUILD = '[0-9]{12}?'/g, "EXTENSION_BUILD = '" + build + "'"))
        .pipe(gulp.dest('../src/ladb_opencutlist/ruby'))
        .pipe(touch());

    // Update version property in constants.js
    return gulp.src('../src/ladb_opencutlist/js/constants.js')
        .pipe(replace(/const EXTENSION_BUILD = '[0-9]{12}?';/g, "const EXTENSION_BUILD = '" + build + "';"))
        .pipe(gulp.dest('../src/ladb_opencutlist/js'))
        .pipe(touch());
});

gulp.task('compile', gulp.series('less_compile', 'css_minify', 'js_minify', 'twig_compile', 'i18n_compile', 'i18n_dialogs_compile'));
gulp.task('build', gulp.series('compile', 'version', 'rbz_create'));

gulp.task('default', gulp.series('build'));

// -----

// C/C++ libs
// ----------
// Warning: These scripts build libraries only on the current operating system architecture.
// Use GitHub action to build Windows and MacOS libs
//
// Example to build 'master' branch (gh = https://cli.github.com/) :
// $ gh workflow run make-c-libs.yml --ref master

var cmakeBuildDir = 'cmake-build';

gulp.task('c_libs_clean', function () {
    return run('cmake --build ' + cmakeBuildDir + ' --target clean', { verbosity: 3 }).exec();
});

gulp.task('c_libs_prepare', function () {

    var config = options.config ? options.config : 'Release';

    return run('cmake -S .. -B ' + cmakeBuildDir + ' -DCMAKE_BUILD_TYPE=' + config, { verbosity: 3 }).exec();
});

gulp.task('c_libs_build', function () {

    var config = options.config ? options.config : 'Release';

    return run('cmake --build ' + cmakeBuildDir + ' --config ' + config + ' --parallel', { verbosity: 3 }).exec();
});

gulp.task('c_libs_install', function () {
    return run('cmake --install ' + cmakeBuildDir, { verbosity: 3 }).exec();
});

gulp.task('c_libs_build_install', gulp.series('c_libs_build', 'c_libs_install'));
gulp.task('c_libs', gulp.series('c_libs_prepare', 'c_libs_build', 'c_libs_install'));
