var through = require('through2');
var path = require('path');
var yaml = require('js-yaml');

var PluginError = require('plugin-error');

module.exports = function (opt) {

    function transform(file, enc, cb) {

        if (file.isNull()) return cb(null, file);
        if (file.isStream()) return cb(new PluginError('gulp-ladb-i18n-yml-zz-compile', 'Streaming not supported'));

        const language = file.stem;

        let data;
        try {

            const contents = file.contents.toString('utf8');
            const ymlDocument = yaml.load(contents);

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
            fillZZValues(ymlDocument);

            data = yaml.dump(ymlDocument, {
                lineWidth: -1,
                quotingType: '"'
            });

        } catch (err) {
            return cb(new PluginError('gulp-ladb-i18n-yml-zz-compile', err));
        }

        file.contents = Buffer.from(data);
        file.path = path.join(file.base, 'zz_' + language + '.yml');

        cb(null, file);
    }

    return through.obj(transform);
};
