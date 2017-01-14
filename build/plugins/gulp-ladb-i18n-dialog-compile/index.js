var through = require('through2');
var gutil = require('gulp-util');
var path = require('path');
var twig = require('twig').twig;
var vinylFile = require('vinyl-file');

var PluginError = gutil.PluginError;

module.exports = function (templateSource, opt) {

    function transform(file, enc, cb) {

        if (file.isNull()) return cb(null, file);
        if (file.isStream()) return cb(new PluginError('gulp-ladb-i18n-dialog-compile', 'Streaming not supported'));

        var data;
        try {

            var filename = file.path.substr(file.base.length);
            var language = filename.substr(0, filename.length - '.yml'.length);

            var templateFile = vinylFile.readSync(templateSource);

            var template = twig({ data: templateFile.contents.toString('utf8') });
            data = template.render({ language:language });

        } catch (err) {
            return cb(new PluginError('gulp-ladb-i18n-dialog-compile', err));
        }

        file.contents = new Buffer(data);
        file.path = file.base + 'dialog-' + language + '.html';

        cb(null, file);
    }

    return through.obj(transform);
};