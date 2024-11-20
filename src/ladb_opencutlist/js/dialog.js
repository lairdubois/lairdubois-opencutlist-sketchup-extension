
// JS -> Ruby interactions

// -- Commands

let commandId = 0;
const commandCallbacks = {};
const commandCallStack = [];
let commandRunning = false;

function rubyCallCommand(command, params, callback) {
    const call = {
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
    const callback = commandCallbacks[id];
    if (typeof callback == 'function') {
        const response = encodedResponse ? JSON.parse(Base64.decode(encodedResponse)) : {};
        callback(response);
        commandCallbacks[id] = null;
    }
    commandRunning = false;
    shiftCommandCallStack();
}

function shiftCommandCallStack() {
    if (!commandRunning) {
        const call = commandCallStack.shift();
        if (call) {
            commandRunning = true;
            const call_json = JSON.stringify(call);
            const encoded_call_json = encodeURIComponent(call_json);
            window.location.href = "skp:ladb_opencutlist_command@" + encoded_call_json;
        }
    }
}

// -- Events

const eventCallbacks = {};

function addEventCallback(event, callback) {
    if (typeof callback == 'function') {
        let events;
        if ($.isArray(event)) {
            events = event;
        } else {
            events = [ event ];
        }
        for (let i = 0; i < events.length; i++) {
            let callbacks = eventCallbacks[events[i]];
            if (!callbacks) {
                callbacks = [];
                eventCallbacks[events[i]] = callbacks;
            }
            callbacks.push(callback);
        }
    }
}

function removeEventCallback(event, callback) {
    let events;
    if ($.isArray(event)) {
        events = event;
    } else {
        events = [ event ];
    }
    for (let i = 0; i < events.length; i++) {
        const callbacks = eventCallbacks[events[i]];
        if (callbacks) {
            for (const j = 0; i < callbacks.length; i++) {
                if (callbacks[j] === callback) {
                    callbacks.splice(i, 1);
                    return;
                }
            }
        }
    }
}

function triggerEvent(event, encodedParams) {
    const callbacks = eventCallbacks[event];
    if (callbacks) {
        const params = encodedParams ? JSON.parse(Base64.decode(encodedParams)) : {};
        for (let i = 0; i < callbacks.length; i++) {
            callbacks[i](params);
        }
    }
}

// -- Startup

function setDialogContext(type, encodedParams) {

    const params = encodedParams ? JSON.parse(Base64.decode(encodedParams)) : {};
    let webglAvailable;
    try {
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('webgl');
        webglAvailable = context && context instanceof WebGLRenderingContext;
    } catch (e) {
        webglAvailable = false;
    }

    rubyCallCommand('core_dialog_loaded', {
        dialog_type: type,
        dialog_params: params,
        webgl_available: webglAvailable
    }, function (response) {
        $('body')['ladbDialog' + type.capitalize()](response);
        rubyCallCommand('core_dialog_ready');
    });

}
