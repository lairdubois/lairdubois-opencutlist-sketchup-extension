
// Chrome 57
// https://vanillajstoolkit.com/polyfills/stringpadstart/
if (!String.prototype.padStart) {
    Object.defineProperty(String.prototype, 'padStart', {
        value: function (targetLength, padString) {
            targetLength = targetLength >> 0; //truncate if number or convert non-number to 0;
            padString = String((typeof padString !== 'undefined' ? padString : ' '));
            if (this.length > targetLength) {
                return String(this);
            } else {
                targetLength = targetLength - this.length;
                if (targetLength > padString.length) {
                    padString += padString.repeat(targetLength / padString.length); //append to original to ensure we are longer than needed
                }
                return padString.slice(0, targetLength) + String(this);
            }
        }
    });
}

// Not standard

if (!String.prototype.nl2br) {
    String.prototype.nl2br = function () {
        return this.replace(/([^>\r\n]?)(\r\n|\n\r|\r|\n)/g, '$1<br>');
    }
}

if (!String.prototype.striptags) {
    String.prototype.striptags = function () {
        return this.replace(/[<]/g, '&lt;').replace(/[>]/g, '&gt;');
    }
}

// Add unique function on Arrays
if (!Array.prototype.unique) {
    Array.prototype.unique = function () {
        var a = this.concat();
        for (var i = 0; i < a.length; ++i) {
            for (var j = i + 1; j < a.length; ++j) {
                if (a[i] === a[j]) {
                    a.splice(j--, 1);
                }
            }
        }
        return a;
    };
}
