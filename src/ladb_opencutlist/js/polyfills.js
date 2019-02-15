
// Add startsWith function to string (Internet Explorer compatibility fix)
// https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/String/startsWith#Proth%C3%A8se_d'%C3%A9mulation_(polyfill)
if (!String.prototype.startsWith) {
    Object.defineProperty(String.prototype, 'startsWith', {
        value: function(search, pos) {
            pos = !pos || pos < 0 ? 0 : +pos;
            return this.substring(pos, pos + search.length) === search;
        }
    });
}

// Add endsWith function to string (Internet Explorer compatibility fix)
// https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/String/endsWith#Proth%C3%A8se_d'%C3%A9mulation_(polyfill)
if (!String.prototype.endsWith) {
    String.prototype.endsWith = function(searchString, position) {
        var subjectString = this.toString();
        if (typeof position !== 'number' || !isFinite(position) || Math.floor(position) !== position || position > subjectString.length) {
            position = subjectString.length;
        }
        position -= searchString.length;
        var lastIndex = subjectString.lastIndexOf(searchString, position);
        return lastIndex !== -1 && lastIndex === position;
    };
}