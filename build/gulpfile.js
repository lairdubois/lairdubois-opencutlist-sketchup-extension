var gulp = require('gulp');
var ladb_twig_compile = require('./plugins/gulp-ladb-twig-compile');
var concat = require('gulp-concat');
var zip = require('gulp-zip');

// Convert twig templates to .js precompiled files
gulp.task('twig_compile', function () {
    'use strict';
    return gulp.src('../src/ladb_toolbox/twig/**/*.twig')
        .pipe(ladb_twig_compile())
        .pipe(concat('twig-templates.js'))
        .pipe(gulp.dest('../src/ladb_toolbox/js/templates'));
});

// Create the .rbz archive
gulp.task('rbz_create', function () {
    return gulp.src(
        [

            '../src/**/*',

            '!../src/**/.DS_store',

            '!../src/**/*.twig',
            '!../src/**/twig/**',
            '!../src/**/twig/'

        ])
        .pipe(zip('ladb_toolbox.rbz'))
        .pipe(gulp.dest('../dist'));
});

gulp.task('compile', ['twig_compile']);
gulp.task('build', ['twig_compile', 'rbz_create']);

gulp.task('default', ['twig_compile', 'rbz_create']);