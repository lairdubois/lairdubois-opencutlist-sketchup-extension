var gulp = require('gulp');
var gulpif = require('gulp-if');
var minimist = require('minimist');
var fs = require('fs');
var gutil = require('gulp-util');
var ladb_twig_compile = require('./plugins/gulp-ladb-twig-compile');
var ladb_i18n_compile = require('./plugins/gulp-ladb-i18n-compile');
var ladb_i18n_dialog_compile = require('./plugins/gulp-ladb-i18n-dialog-compile');
var concat = require('gulp-concat');
var zip = require('gulp-zip');
var less = require('gulp-less');
var replace = require('gulp-replace');

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
    return gulp.src('../src/ladb_opencutlist/yaml/i18n/*.yml')
        .pipe(ladb_i18n_compile())
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
        .pipe(gulpif(options.env === 'prod', zip('ladb_opencutlist.rbz'), zip('ladb_opencutlist-' + options.env + '.rbz')))
        .pipe(gulp.dest('../dist'));
});

// Version

gulp.task('version', function () {

    // Retrive version from package.json
    var pkg = JSON.parse(fs.readFileSync('./package.json'));
    var version = pkg.version;

    // Compute build from current date
    var nowISO = (new Date()).toISOString();
    var build = nowISO.slice(0,10).replace(/-/g, "") + nowISO.slice(11,16).replace(/:/g, "");

    // Update version property in plugin.rb
    return gulp.src('../src/ladb_opencutlist/ruby/plugin.rb')
        .pipe(replace(/VERSION = '[0-9.]+(-alpha|-dev)?'/g, "VERSION = '" + version + "'"))
        .pipe(replace(/BUILD = '[0-9.]{12}?'/g, "BUILD = '" + build + "'"))
        .pipe(gulp.dest('../src/ladb_opencutlist/ruby'));
});

gulp.task('compile', ['less_compile', 'twig_compile', 'i18n_compile', 'i18n_dialog_compile']);
gulp.task('build', ['compile', 'version', 'rbz_create']);

gulp.task('default', ['build']);