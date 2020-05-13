var gulp = require('gulp');
var gulpif = require('gulp-if');
var minimist = require('minimist');
var fs = require('fs');
var ladb_twig_compile = require('./plugins/gulp-ladb-twig-compile');
var ladb_i18n_compile = require('./plugins/gulp-ladb-i18n-compile');
var ladb_i18n_dialog_compile = require('./plugins/gulp-ladb-i18n-dialog-compile');
var concat = require('gulp-concat');
var zip = require('gulp-zip');
var less = require('gulp-less');
var replace = require('gulp-replace');
var glob = require('glob');
var yaml = require('js-yaml');
var path = require('path');

var knownOptions = {
    string: 'env',
    default: { env: process.env.NODE_ENV || 'prod' }
};

var options = minimist(process.argv.slice(2), knownOptions);

// Convert less to .css files
gulp.task('less_compile', function () {
    return gulp.src('../src/ladb_opencutlist/less/ladb-opencutlist.less')
        .pipe(less())
        .pipe(gulp.dest('../src/ladb_opencutlist/css'));
});

// Convert twig runtime templates to .js precompiled files
gulp.task('twig_compile', function () {
    'use strict';
    return gulp.src(
        [
            '../src/ladb_opencutlist/twig/**/*.twig',
            '!../src/ladb_opencutlist/twig/dialog.twig'     // dialog.twig is used on build time then it is excluded from this task.
        ])
        .pipe(ladb_twig_compile())
        .pipe(concat('twig-templates.js'))
        .pipe(gulp.dest('../src/ladb_opencutlist/js/templates'));
});

// Convert yaml i18n to .js files
gulp.task('i18n_compile', function () {

    var languageLabels = {};
    var ymlFiles = glob.sync('../src/ladb_opencutlist/yaml/i18n/*.yml');
    ymlFiles.forEach(function (ymlFile) {
        var contents = fs.readFileSync(ymlFile);
        var ymlDocument = yaml.safeLoad(contents);
        if ('_label' in ymlDocument) {
            languageLabels[path.basename(ymlFile, '.yml')] = ymlDocument['_label'];
        }
    });

    return gulp.src('../src/ladb_opencutlist/yaml/i18n/*.yml')
        .pipe(ladb_i18n_compile(languageLabels))
        .pipe(gulp.dest('../src/ladb_opencutlist/js/i18n'));
});

// Compile dialog.twig to dialog-XX.html files - this permits to avoid dynamic loading on runtime
gulp.task('i18n_dialog_compile', function () {
    return gulp.src('../src/ladb_opencutlist/yaml/i18n/*.yml')
        .pipe(ladb_i18n_dialog_compile('../src/ladb_opencutlist/twig/dialog.twig'))
        .pipe(gulp.dest('../src/ladb_opencutlist/html'));
});

// Create the .rbz archive
gulp.task('rbz_create', function () {
    return gulp.src(
        [

            '../src/**/*',

            '!../src/**/.DS_store',

            '!../src/**/*.less',
            '!../src/**/less/**',
            '!../src/**/less/',

            '!../src/**/*.twig',
            '!../src/**/twig/**',
            '!../src/**/twig/'

        ])
        .pipe(gulpif(options.env.toLowerCase() === 'prod', zip('ladb_opencutlist.rbz'), zip('ladb_opencutlist-' + options.env.toLowerCase() + '.rbz')))
        .pipe(gulp.dest('../dist'));
});

// Version

gulp.task('version', function () {

    // Retrive version from package.json
    var pkg = JSON.parse(fs.readFileSync('./package.json'));
    var version = pkg.version + (options.env.toLowerCase() === 'prod' ? '' : '-' + options.env.toLowerCase());

    // Compute build from current date
    var nowISO = (new Date()).toISOString();
    var build = nowISO.slice(0,10).replace(/-/g, "") + nowISO.slice(11,16).replace(/:/g, "");

    // Update version property in manifest.json
    gulp.src('../dist/manifest' + (options.env.toLowerCase() === 'prod' ? '' : '-' + options.env.toLowerCase()) + '.json')
        .pipe(replace(/"version": "[0-9.]+(-[a-z]*)?"/g, '"version": "' + version + '"'))
        .pipe(replace(/"build": "[0-9]{12}?"/g, '"build": "' + build + '"'))
        .pipe(gulp.dest('../dist'));

    // Update version property in plugin.rb
    return gulp.src('../src/ladb_opencutlist/ruby/constants.rb')
        .pipe(replace(/EXTENSION_VERSION = '[0-9.]+(-[a-z]*)?'/g, "EXTENSION_VERSION = '" + version + "'"))
        .pipe(replace(/EXTENSION_BUILD = '[0-9]{12}?'/g, "EXTENSION_BUILD = '" + build + "'"))
        .pipe(gulp.dest('../src/ladb_opencutlist/ruby'));
});

gulp.task('compile', gulp.series('less_compile', 'twig_compile', 'i18n_compile', 'i18n_dialog_compile'));
gulp.task('build', gulp.series('compile', 'version', 'rbz_create'));

gulp.task('default', gulp.series('build'));