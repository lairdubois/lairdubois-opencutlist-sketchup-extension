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
var globSync = require('glob').globSync;
var yaml = require('js-yaml');
var path = require('path');
var cleanCSS = require('gulp-clean-css');
var uglify = require('gulp-uglify');
var postcss = require('gulp-postcss');
var pxtorem = require('postcss-pxtorem');
var spawn = require('child_process').spawn;

var knownOptions = {
    string: 'env',
    default: { env: process.env.NODE_ENV || 'prod' }
};

var options = minimist(process.argv.slice(2), knownOptions);
var isProd = options.env.toLowerCase() === 'prod';

// Bundling -- concatenate the dialogs' vendor/app CSS+JS files into a
// handful of files instead of loading ~70 of them individually (each one is
// an extra request/response round-trip, even against the loopback HTTP
// server used to serve the dialogs). Order matters (no module resolution,
// just plain concatenation) and must match dialog-tabs.twig / dialog-modal.twig.
var JS_BASE = '../src/ladb_opencutlist/js/';
var JS_BUNDLES_DEST = '../src/ladb_opencutlist/js/bundles';
var CSS_BASE = '../src/ladb_opencutlist/css/';

function withBase(base, files) {
    return files.map(function (file) { return base + file; });
}

var VENDOR_CSS_FILES = withBase(CSS_BASE, [
    'lib/bootstrap.min.css',
    'lib/bootstrap-select.min.css',
    'lib/bootstrap-slider.min.css',
    'lib/bootstrap-tokenfield.min.css',
    'lib/codemirror.min.css',
    'lib/codemirror-hint-show-hint.min.css',
    'lib/noty.min.css',
    'lib/jquery-ui.min.css',
    'lib/jquery-ui.theme.min.css',
]);

// Shared by both dialogs (qrcode is only used by the tabs dialog, but it's
// small enough to include here so both dialogs reuse the exact same bundle).
var COMMON_JS_FILES = withBase(JS_BASE, [
    'constants.js',
    'polyfills.js',
    'lib/jquery-3.7.1.min.js',
    'lib/jquery-ui.min.js',
    'lib/jquery.textcomplete.min.js',
    'lib/bootstrap.min.js',
    'lib/bootstrap-select.min.js',
    'lib/bootstrap-slider.min.js',
    'lib/bootstrap-tokenfield.min.js',
    'lib/twig.min.js',
    'lib/base64.min.js',
    'lib/i18next.min.js',
    'lib/noty.min.js',
    'lib/codemirror.min.js',
    'lib/codemirror-display-autorefresh.min.js',
    'lib/codemirror-display-placeholder.min.js',
    'lib/codemirror-edit-closebrackets.min.js',
    'lib/codemirror-edit-matchbrackets.min.js',
    'lib/codemirror-hint-show-hint.min.js',
    'lib/codemirror-mode-ruby.min.js',
    'lib/codemirror-mode-simple.min.js',
    'lib/qrcode.min.js',
]);
var TABS_JS_FILES = withBase(JS_BASE, [
    'plugins/components/jquery.ladb.bottombar.js',
    'plugins/components/jquery.ladb.leftbar.js',
    'plugins/components/jquery.ladb.abstract-textinput.js',
    'plugins/components/jquery.ladb.textinput-area.js',
    'plugins/components/jquery.ladb.textinput-code.js',
    'plugins/components/jquery.ladb.textinput-color.js',
    'plugins/components/jquery.ladb.textinput-dimension.js',
    'plugins/components/jquery.ladb.textinput-file.js',
    'plugins/components/jquery.ladb.textinput-number-with-unit.js',
    'plugins/components/jquery.ladb.textinput-size.js',
    'plugins/components/jquery.ladb.textinput-text.js',
    'plugins/components/jquery.ladb.textinput-tokenfield.js',
    'plugins/components/jquery.ladb.textinput-url.js',
    'plugins/components/jquery.ladb.editor-export.js',
    'plugins/components/jquery.ladb.editor-label-layout.js',
    'plugins/components/jquery.ladb.editor-label-offset.js',
    'plugins/components/jquery.ladb.editor-std-attributes.js',
    'plugins/components/jquery.ladb.editor-sizes.js',
    'plugins/components/jquery.ladb.three-viewer.js',
    'plugins/components/jquery.ladb.widget-preset.js',
    'plugins/jquery.ladb.abstract-dialog.js',
    'plugins/jquery.ladb.dialog-tabs.js',
    'plugins/tabs/jquery.ladb.abstract-tab.js',
    'plugins/tabs/jquery.ladb.tab-materials.js',
    'plugins/tabs/jquery.ladb.tab-cutlist.js',
    'plugins/tabs/jquery.ladb.tab-outliner.js',
    'plugins/tabs/jquery.ladb.tab-importers.js',
    'plugins/tabs/jquery.ladb.tab-tutorials.js',
    'plugins/tabs/jquery.ladb.tab-news.js',
    'plugins/tabs/jquery.ladb.tab-forum.js',
    'plugins/tabs/jquery.ladb.tab-sponsor.js',
    'plugins/tabs/jquery.ladb.tab-settings.js',
    'plugins/tabs/jquery.ladb.tab-about.js',
    'templates/components-twig-templates.js',
    'templates/core-twig-templates.js',
    'templates/tabs-twig-templates.js',
    'dialog.js',
    'dialog-tabs.js',
]);
var MODAL_JS_FILES = withBase(JS_BASE, [
    'plugins/components/jquery.ladb.leftbar.js',
    'plugins/components/jquery.ladb.abstract-textinput.js',
    'plugins/components/jquery.ladb.textinput-area.js',
    'plugins/components/jquery.ladb.textinput-code.js',
    'plugins/components/jquery.ladb.textinput-color.js',
    'plugins/components/jquery.ladb.textinput-dimension.js',
    'plugins/components/jquery.ladb.textinput-file.js',
    'plugins/components/jquery.ladb.textinput-number-with-unit.js',
    'plugins/components/jquery.ladb.textinput-text.js',
    'plugins/components/jquery.ladb.textinput-tokenfield.js',
    'plugins/components/jquery.ladb.textinput-url.js',
    'plugins/components/jquery.ladb.editor-export.js',
    'plugins/components/jquery.ladb.editor-label-layout.js',
    'plugins/components/jquery.ladb.editor-label-offset.js',
    'plugins/components/jquery.ladb.editor-std-attributes.js',
    'plugins/components/jquery.ladb.three-viewer.js',
    'plugins/components/jquery.ladb.widget-preset.js',
    'plugins/jquery.ladb.abstract-dialog.js',
    'plugins/jquery.ladb.dialog-modal.js',
    'plugins/modals/jquery.ladb.abstract-modal.js',
    'plugins/modals/jquery.ladb.modal-smart-draw-tool-action-0.js',
    'plugins/modals/jquery.ladb.modal-smart-draw-tool-action-1.js',
    'plugins/modals/jquery.ladb.modal-smart-draw-tool-action-2.js',
    'plugins/modals/jquery.ladb.modal-smart-draw-tool-action-3.js',
    'plugins/modals/jquery.ladb.modal-smart-reshape-tool-action-1.js',
    'plugins/modals/jquery.ladb.modal-smart-join-tool-action-0.js',
    'plugins/modals/jquery.ladb.modal-smart-join-tool-action-2.js',
    'plugins/modals/jquery.ladb.modal-smart-export-tool-action-0.js',
    'plugins/modals/jquery.ladb.modal-smart-export-tool-action-1.js',
    'plugins/modals/jquery.ladb.modal-smart-export-tool-action-2.js',
    'plugins/modals/jquery.ladb.modal-smart-export-tool-action-3.js',
    'templates/components-twig-templates.js',
    'templates/core-twig-templates.js',
    'templates/modals-twig-templates.js',
    'dialog.js',
    'dialog-modal.js',
]);

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
        .pipe(postcss([ pxtorem({ minPixelValue: 1, propList: [
            'font', 'font-size',
                'line-height',
                'letter-spacing',
                'width', 'min-width',
                'height', 'min-height',
                'padding', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
                'margin', 'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
                'top', 'right', 'bottom', 'left',
                'border-width',
                'gap'
            ] }) ]))
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

// Concatenate vendor CSS files into one bundle
gulp.task('css_bundle', function () {
    return gulp.src(VENDOR_CSS_FILES)
        .pipe(concat('vendor.min.css'))
        .pipe(gulp.dest('../src/ladb_opencutlist/css'));
});

// Concatenate the vendor JS libs shared by both dialogs into one bundle
gulp.task('js_bundle_common', function () {
    return gulp.src(COMMON_JS_FILES)
        .pipe(concat('common-bundle.js', { newLine: ';\n' }))
        .pipe(gulp.dest(JS_BUNDLES_DEST));
});

// Concatenate the tabs dialog's app-level plugins + compiled twig templates +
// bootstrap entry scripts (dialog.js/dialog-tabs.js only kick off async
// initialization on $(document).ready, well after i18n has loaded regardless
// of tag order, so they're safe to fold in here instead of a separate tail file)
gulp.task('js_bundle_tabs', function () {
    return gulp.src(TABS_JS_FILES)
        .pipe(concat('tabs-bundle.js', { newLine: ';\n' }))
        .pipe(gulp.dest(JS_BUNDLES_DEST));
});

// Concatenate the modal dialog's app-level plugins + compiled twig templates + bootstrap entry scripts
gulp.task('js_bundle_modal', function () {
    return gulp.src(MODAL_JS_FILES)
        .pipe(concat('modal-bundle.js', { newLine: ';\n' }))
        .pipe(gulp.dest(JS_BUNDLES_DEST));
});

gulp.task('bundle', gulp.series(
    function cleanBundles(cb) {
        del.sync(JS_BUNDLES_DEST + '/*', { force: true });
        cb();
    },
    gulp.parallel('css_bundle', 'js_bundle_common', 'js_bundle_tabs', 'js_bundle_modal')
));

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

    globSync(yamlSrcPath + '*.yml').sort().forEach(function (ymlFile) {    // .sort() because glob >= 9 no longer sorts results
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
        if (language !== sourceLanguage && language !== defaultLanguage) {
            fillDefaultValues(destYmlDocument, defaultYmlDocument);
        }

        if (!isProd) {

            const destZzYmlDocument = JSON.parse(JSON.stringify(destYmlDocument));
            let index = 0;
            const fillZZValues = function (doc) {
                for (var key in doc) {
                    if (typeof doc[key] === 'string') {
                        index++;
                        if (!doc[key].match(/^\$t\([a-z0-9_.]+\)$/i)) {
                            doc[key] = index + ' - ' + doc[key];
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

        deleteHiddenKeys(destYmlDocument);

        fs.writeFileSync(yamlDestPath + language + '.yml', yaml.dump(destYmlDocument, {
            lineWidth: -1,
            quotingType: '"'
        }), (err) => {
            if (err) {
                console.log(err);
            }
        });


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
        'src/**',
        '!src/**/.*',                   // Exclude hidden files (.DS_Store, ...)
        '!src/**/*.less',
        '!src/**/*.twig',
        '!src/**/!(*.min).css',         // Exclude not minified .css files
        '!src/**/css/lib/**',
        '!src/**/js/lib/**',
        '!src/**/js/templates/**',       // Bundled into js/bundles/tabs-bundle.js and modal-bundle.js
        '!src/**/js/plugins/**',         // Bundled into js/bundles/tabs-bundle.js and modal-bundle.js
        '!src/**/js/constants.js',       // Bundled into js/bundles/common-bundle.js
        '!src/**/js/polyfills.js',       // Bundled into js/bundles/common-bundle.js
        '!src/**/js/dialog.js',          // Bundled into js/bundles/tabs-bundle.js and modal-bundle.js
        '!src/**/js/dialog-tabs.js',     // Bundled into js/bundles/tabs-bundle.js
        '!src/**/js/dialog-modal.js',    // Bundled into js/bundles/modal-bundle.js
        '!src/**/less/**',
        '!src/**/twig/**',
        '!src/**/cpp/**',
        '!src/**/bin/**/!(*.dylib|*.dll)',
        '!src/**/yaml/i18n-src/**',
    ];
    if (isProd) {
        // Exclude zz debug languages in prod environment
        blob.push('!src/**/yaml/i18n/zz*.yml');
    }
    // encoding: false is required since gulp 5 to avoid corrupting binary files (.dylib, .dll, images, fonts)
    return gulp.src(blob, { cwd: '../', encoding: false })
        .pipe(zip('ladb_opencutlist.rbz'))
        .pipe(gulp.dest('../dist', { encoding: false }));
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

gulp.task('compile', gulp.series('less_compile', 'css_minify', 'js_minify', 'twig_compile', 'i18n_compile', 'bundle', 'i18n_dialogs_compile'));
gulp.task('build', gulp.series('version', 'compile', 'rbz_create'));

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

function runCommand(command) {
    return new Promise(function (resolve, reject) {
        var child = spawn(command, { shell: true, stdio: 'inherit' });
        child.on('error', reject);
        child.on('exit', function (code) {
            if (code === 0) {
                resolve();
            } else {
                reject(new Error("Command '" + command + "' exited with code " + code));
            }
        });
    });
}

gulp.task('c_libs_clean', function () {
    return runCommand('cmake --build ' + cmakeBuildDir + ' --target clean');
});

gulp.task('c_libs_prepare', function () {

    var config = options.config ? options.config : 'Release';

    return runCommand('cmake -S .. -B ' + cmakeBuildDir + ' -DCMAKE_BUILD_TYPE=' + config + ' --fresh');
});

gulp.task('c_libs_build', function () {

    var config = options.config ? options.config : 'Release';

    return runCommand('cmake --build ' + cmakeBuildDir + ' --config ' + config + ' --parallel');
});

gulp.task('c_libs_install', function () {
    return runCommand('cmake --install ' + cmakeBuildDir);
});

gulp.task('c_libs_build_install', gulp.series('c_libs_build', 'c_libs_install'));
gulp.task('c_libs', gulp.series('c_libs_prepare', 'c_libs_build', 'c_libs_install'));
