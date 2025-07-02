var through = require('through2');
var path = require('path');
var yaml = require('js-yaml');

var markdownIt = require('markdown-it');
var externalLinks = require('markdown-it-external-links');
var md = markdownIt({
    html: true,
    linkify: false,
    typographer: true,
    breaks: true
}).use(externalLinks, {
    externalTarget: '_blank'
});
md.linkify.set({ fuzzyEmail: false });  // disables converting email to link

var PluginError = require('plugin-error');

module.exports = function (languageLabels, languageDisabledMsgs, languageReloadMsgs, opt) {

    // Delete keys that starts by "_"
    function deleteHiddenKeys(doc) {
        for (var key in doc) {
            if (doc.hasOwnProperty(key)) {
                if (key.startsWith('_')) {
                    delete doc[key];
                } else if (typeof doc[key] == 'object') {
                    deleteHiddenKeys(doc[key]);
                }
            }
        }
    }

    // Process markdown on string values
    function markownValues(doc) {
        for (var key in doc) {
            if (doc.hasOwnProperty(key)) {
                if (typeof doc[key] == 'string') {
                    doc[key] = md.renderInline(doc[key]);
                } else if (typeof doc[key] == 'object') {
                    markownValues(doc[key]);
                }
            }
        }
    }

    function transform(file, enc, cb) {

        if (file.isNull()) return cb(null, file);
        if (file.isStream()) return cb(new PluginError('gulp-ladb-i18n-compile', 'Streaming not supported'));

        var data;
        try {

            var contents = file.contents.toString('utf8');
            var ymlDocument = yaml.safeLoad(contents);

            deleteHiddenKeys(ymlDocument);
            markownValues(ymlDocument);

            // Append languages labels
            ymlDocument['language'] = languageLabels;

            // Append languages disabled msgs (and mardown them)
            for (var key in languageDisabledMsgs) {
                languageDisabledMsgs[key] = md.renderInline(languageDisabledMsgs[key]);
            }
            ymlDocument['language_disabled_msg'] = languageDisabledMsgs;

            // Append languages reload msgs (and mardown them)
            for (var key in languageReloadMsgs) {
                languageReloadMsgs[key] = md.renderInline(languageReloadMsgs[key]);
            }
            ymlDocument['language_reload_msg'] = languageReloadMsgs;

            var language = file.stem;

            var resources = {};
            resources[language] = {
                translation: ymlDocument
            };
            var i18nextOptions = {
                lng: language,
                resources: resources
            };

            data = 'i18next.init(' + JSON.stringify(i18nextOptions) + ');';

        } catch (err) {
            return cb(new PluginError('gulp-ladb-i18n-compile', err));
        }

        file.contents = Buffer.from(data);
        file.path = path.join(file.base, language + '.js');

        cb(null, file);
    }

    return through.obj(transform);
};
