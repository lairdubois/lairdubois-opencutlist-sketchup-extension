var through = require('through2');
var twig = require('twig').twig;
var merge = require('merge');
var slash = require('slash');

var PluginError = require('plugin-error');

module.exports = function (prefix, opt) {

    function transform(file, enc, cb) {

        if (file.isNull()) return cb(null, file);
        if (file.isStream()) return cb(new PluginError('gulp-ladb-twig-compile', 'Streaming not supported'));

        var options = merge({
            allowInlineIncludes: true,
            twig: 'twig'
        }, opt);
        var data;
        try {

            var template = twig({ id: slash(prefix + file.relative), data: file.contents.toString('utf8') });
            data = template.compile(options);

            // LADB Sanitize
            data = data.replace('twig({', 'Twig.twig({allowInlineIncludes:true, ');

            // Fix for compiling on Windows (including slash above)
            data = data.replace(/\\r\\n/g, '\\n');

        } catch (err) {
            return cb(new PluginError('gulp-ladb-twig-compile', err));
        }

        file.contents = Buffer.from(data);
        file.path = file.path + '.js';

        cb(null, file);
    }

    return through.obj(transform);
};
