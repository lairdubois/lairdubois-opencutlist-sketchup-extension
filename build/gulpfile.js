var gulp = require('gulp');
var fs = require('fs');
var gutil = require('gulp-util');
var ladb_twig_compile = require('./plugins/gulp-ladb-twig-compile');
var ladb_i18n_compile = require('./plugins/gulp-ladb-i18n-compile');
var ladb_i18n_dialog_compile = require('./plugins/gulp-ladb-i18n-dialog-compile');
var concat = require('gulp-concat');
var zip = require('gulp-zip');
var less = require('gulp-less');
var replace = require('gulp-replace');

// Convert less to .css files
gulp.task('less_compile', function () {
    return gulp.src('../src/ladb_toolbox/less/ladb-toolbox.less')
        .pipe(less())
        .pipe(gulp.dest('../src/ladb_toolbox/css'));
});

// Convert twig runtime templates to .js precompiled files
gulp.task('twig_compile', function () {
    'use strict';
    return gulp.src(
        [
            '../src/ladb_toolbox/twig/**/*.twig',
            '!../src/ladb_toolbox/twig/dialog.twig'     // dialog.twig is used on build time then it is excluded from this task.
        ])
        .pipe(ladb_twig_compile())
        .pipe(concat('twig-templates.js'))
        .pipe(gulp.dest('../src/ladb_toolbox/js/templates'));
});

// Convert yaml i18n to .js files
gulp.task('i18n_compile', function () {
    return gulp.src('../src/ladb_toolbox/yaml/i18n/*.yml')
        .pipe(ladb_i18n_compile())
        .pipe(gulp.dest('../src/ladb_toolbox/js/i18n'));
});

// Compile dialog.twig to dialog-XX.html files - this permits to avoid dynamic loading on runtime
gulp.task('i18n_dialog_compile', function () {
    return gulp.src('../src/ladb_toolbox/yaml/i18n/*.yml')
        .pipe(ladb_i18n_dialog_compile('../src/ladb_toolbox/twig/dialog.twig'))
        .pipe(gulp.dest('../src/ladb_toolbox/html'));
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
            '!../src/**/twig/'//,

            // '!../src/**/*.yml',
            // '!../src/**/yaml/**',
            // '!../src/**/yaml/'

        ])
        .pipe(zip('ladb_toolbox.rbz'))
        .pipe(gulp.dest('../dist'));
});

// Version

gulp.task('version', function () {

    // Retrive version from package.json
    var pkg = JSON.parse(fs.readFileSync('./package.json'));
    var version = pkg.version;

    // Update version property in plugin.rb
    gulp.src('../src/ladb_toolbox/ruby/plugin.rb')
        .pipe(replace(/VERSION = '[0-9.]+(-alpha|-beta)?'/g, "VERSION = '" + version + "'"))
        .pipe(gulp.dest('../src/ladb_toolbox/ruby'));

    // Update VERSION file in dist folder
    function writeStringToFile(filename, string) {
        var src = require('stream').Readable({ objectMode: true });
        src._read = function () {
            this.push(new gutil.File({
                cwd: "",
                base: "",
                path: filename,
                contents: new Buffer(string)
            }));
            this.push(null)
        };
        return src
    }

    return writeStringToFile("VERSION", pkg.version)
        .pipe(gulp.dest('../dist'))
});

gulp.task('compile', ['less_compile', 'twig_compile', 'i18n_compile', 'i18n_dialog_compile']);
gulp.task('build', ['compile', 'version', 'rbz_create']);

gulp.task('default', ['build']);