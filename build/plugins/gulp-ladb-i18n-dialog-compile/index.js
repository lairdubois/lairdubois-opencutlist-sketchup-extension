var through = require('through2');
var path = require('path');
var twig = require('twig').twig;
var vinylFile = require('vinyl-file');

var PluginError = require('plugin-error');

module.exports = function (templateSource, opt) {

    function transform(file, enc, cb) {

        if (file.isNull()) return cb(null, file);
        if (file.isStream()) return cb(new PluginError('gulp-ladb-i18n-dialog-compile', 'Streaming not supported'));

        var data;
        try {

            var language = file.stem;

            var templateFile = vinylFile.readSync(templateSource);

            var template = twig({ data: templateFile.contents.toString('utf8') });
            data = template.render({ language:language });

        } catch (err) {
            return cb(new PluginError('gulp-ladb-i18n-dialog-compile', err));
        }

        file.contents = Buffer.from(data);
        file.path = path.join(file.base, templateFile.stem + '-' + language + '.html');

        cb(null, file);
    }

    return through.obj(transform);
};
