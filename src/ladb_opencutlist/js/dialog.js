
// Add .ie class on boby tag if running on IE. Used for special workarounds
if (navigator.appName === 'Microsoft Internet Explorer') {
    if (navigator.appVersion.indexOf("MSIE 9")) {
        $('body').addClass('ie ie-9');
    } else if (navigator.appVersion.indexOf("MSIE 10")) {
        $('body').addClass('ie ie-10 ie-gt9');
    } else if (navigator.appVersion.indexOf("MSIE 11")) {
        $('body').addClass('ie ie-11 ie-gt9 ie-gt10');
    } else {
        $('body').addClass('ie');
    }
}

// JS -> Ruby interactions

// -- Commands

var commandId = 0;
var commandCallbacks = {};
var commandCallStack = [];
var commandRunning = false;
var maxCommandCallLength = $('body').hasClass('ie') ? 2000 : Number.MAX_SAFE_INTEGER;

function rubyCallCommand(command, params, callback) {
    var call = {
        id: commandId,
        command: command,
        params: params
    };
    commandCallbacks[commandId] = callback;
    commandId++;
    commandCallStack.push(call);
    shiftCommandCallStack();
}

function rubyCommandCallback(id, encodedResponse) {
    var callback = commandCallbacks[id];
    if (callback && typeof callback == 'function') {
        var response = encodedResponse ? JSON.parse(Base64.decode(encodedResponse)) : {};
        callback(response);
        commandCallbacks[id] = null;
    }
    commandRunning = false;
    shiftCommandCallStack();
}

function shiftCommandCallStack() {
    if (!commandRunning) {
        var call = commandCallStack.shift();
        if (call) {
            commandRunning = true;
            var call_json = JSON.stringify(call);
            if (call_json.length > maxCommandCallLength) {
                // Split json string into multiple chunks to avoid IE url parameter max size = 2048
                var chunks = call_json.match(new RegExp('.{1,' + maxCommandCallLength + '}', 'g'));
                for (var i = 0 ; i < chunks.length; i++) {
                    window.location.href = "skp:ladb_opencutlist_command@" + i + "/" + (chunks.length - 1) + "/" + chunks[i];
                }
            } else {
                window.location.href = "skp:ladb_opencutlist_command@0/0/" + encodeURIComponent(call_json);
            }
        }
    }
}

// -- Events

var eventCallbacks = {};

function addEventCallback(event, callback) {
    if (typeof callback == 'function') {
        var events;
        if ($.isArray(event)) {
            events = event;
        } else {
            events = [ event ];
        }
        for (var i = 0; i < events.length; i++) {
            var callbacks = eventCallbacks[events[i]];
            if (!callbacks) {
                callbacks = [];
                eventCallbacks[events[i]] = callbacks;
            }
            callbacks.push(callback);
        }
    }
}

function removeEventCallback(event, callback) {
    var events;
    if ($.isArray(event)) {
        events = event;
    } else {
        events = [ event ];
    }
    for (var i = 0; i < events.length; i++) {
        var callbacks = eventCallbacks[events[i]];
        if (callbacks) {
            for (var j = 0; i < callbacks.length; i++) {
                if (callbacks[j] === callback) {
                    callbacks.splice(i, 1);
                    return;
                }
            }
        }
    }
}

function triggerEvent(event, encodedParams) {
    var callbacks = eventCallbacks[event];
    if (callbacks) {
        var params = encodedParams ? JSON.parse(Base64.decode(encodedParams)) : {};
        for (var i = 0; i < callbacks.length; i++) {
            callbacks[i](params);
        }
    }
}

// Ready !

$(document).ready(function () {
    rubyCallCommand('core_dialog_loaded', null, function (response) {
        $('body').ladbDialog(response);
        rubyCallCommand('core_dialog_ready');
    });
});

