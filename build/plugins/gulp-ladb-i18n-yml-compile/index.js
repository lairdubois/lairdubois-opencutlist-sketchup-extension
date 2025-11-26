var through = require('through2');
var path = require('path');
var yaml = require('js-yaml');

var PluginError = require('plugin-error');

module.exports = function (sourceLanguage, defaultLanguage, defaultYmlDocument, opt) {

    // Delete keys that starts by "_"
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

    function transform(file, enc, cb) {

        if (file.isNull()) return cb(null, file);
        if (file.isStream()) return cb(new PluginError('gulp-ladb-i18n-yml-compile', 'Streaming not supported'));

        const language = file.stem;

        let data;
        try {

            const contents = file.contents.toString('utf8');
            const ymlDocument = yaml.load(contents);

            deleteHiddenKeys(ymlDocument);
            if (language !== sourceLanguage && language !== defaultLanguage) {
                fillDefaultValues(ymlDocument, defaultYmlDocument);
            }

            data = yaml.dump(ymlDocument, {
                lineWidth: -1,
                quotingType: '"'
            });

        } catch (err) {
            return cb(new PluginError('gulp-ladb-i18n-yml-compile', err));
        }

        file.contents = Buffer.from(data);
        file.path = path.join(file.base, language + '.yml');

        cb(null, file);
    }

    return through.obj(transform);
};
