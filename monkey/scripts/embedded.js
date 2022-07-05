// ==UserScript==
// @name         TamperMonkey Helper Functions
// @namespace    http://tampermonkey.net/
// @version      0.1-11
// @description  Try to take over the world!
// @author       XXTouch Team.
// @match        https://*/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    
    /* Matching request from native layer */
    const $$matchingRequest = function () {
        //* ${MATCHING} *//
        return null;
    }();
    
    
    /* The Very Important Payload (VIP) from native layer */
    const $$payloadFunction = function (TamperMonkey) {
        //* ${PAYLOAD} *//
    };


    /* Helper functions */
	const $$sharedHelpers = {};
    
    
    /**
     * Print native logs via `NSLog(...)`.
     * @param obj Any object to be printed.
     */
    $$sharedHelpers.postMessage = function (obj) {
        window.webkit.messageHandlers.$_TM_WKNativeLog.postMessage(obj);
    };


    window.$_TM_WKHandlerID = 1;
    window.$_TM_WKHandlers = {};
    window.$_TM_WKHandlerOnMessageReceive = function (msg) {
        if (typeof(msg) === 'object' && msg.id !== undefined && msg.data !== undefined && msg.error !== undefined) {
            const handle = msg.id;
            const data = msg.data;
            const error = msg.error;
            
            if (window.$_TM_WKHandlers.hasOwnProperty(handle)) {
                console.debug("callback with handle " + handle);
                
                if (error !== null) {
                    window.$_TM_WKHandlers[handle].reject(window.atob(error));
                } else {
                    window.$_TM_WKHandlers[handle].resolve(JSON.parse(window.atob(data)));
                }
                
                delete window.$_TM_WKHandlers[handle];
            } else {
                // dispatch return values to all child frames
                const frames = window.frames;
                for (let i = 0; i < frames.length; i++) {
                    frames[i].postMessage(msg, '*');
                }
            }
            
            return true;
        }
        return false;
    };
    // noinspection JSVoidFunctionReturnValueUsed
    $$sharedHelpers.$_TM_onmessage = window.addEventListener("message", (event) => {
        // receive messages from parent window
        window.$_TM_WKHandlerOnMessageReceive(event.data);
    });
    
    
    /**
     * Send unlimited url request (no cross-origin restrictions) via `NSURLSession`.
     * @param details See: https://wiki.greasespot.net/GM.xmlHttpRequest
     */
    $$sharedHelpers.xmlHttpRequest = function (details) {
        const onloadCallback = details.onload || function () {};
        const onerrorCallback = details.onerror || function () {};
        
        delete details.onload;
        delete details.onerror;
        
        let p = new Promise((resolve, reject) => {
            const handle = 'm' + window.$_TM_WKHandlerID++;
            window.$_TM_WKHandlers[handle] = { resolve, reject };
            window.webkit.messageHandlers.$_TM_WKNativeRequestSync.postMessage({ id: handle, data: details });
        });
        
        p.then(onloadCallback).catch(onerrorCallback);
        return true;
    };


	/**
	 * Scroll a DOM element to visible area.
	 * @param {HTMLElement} el The element to be scrolled.
	 */
	$$sharedHelpers.scrollToElement = function (el) {
		// Non-standard: https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoViewIfNeeded
		if (typeof el.scrollIntoViewIfNeeded === 'function') {
			el.scrollIntoViewIfNeeded();
			return true;
		}
		/**
		 * Check if an element is visible in current view-port.
		 * @param {HTMLElement} el The element to be tested.
		 * @returns A boolean value indicates the visible status.
		 */
		function isInViewport(el) {
			const bounding = el.getBoundingClientRect();
			return (
				bounding.top >= 0 &&
				bounding.left >= 0 &&
				bounding.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
				bounding.right <= (window.innerWidth || document.documentElement.clientWidth)
			);
		}
		if (el === null) { return false; }
		if (isInViewport(el)) { return false; }
		// Experimental: https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView
		el.scrollIntoView({
			'block': 'nearest',
			'inline': 'nearest',
		}); // the same as: `el.scrollIntoView(true);`
		return true;
	};


	/**
	 * Highlight DOM element with random color.
	 * @param {HTMLElement} el The element to be highlighted.
	 */
	$$sharedHelpers.highlightElement = function (el) {
		if (el === null) { return false; }
		function getRandomColor() {
			const letters = '0123456789ABCDEF';
			let color = '#';
			for (let i = 0; i < 6; i++) {
				color += letters[Math.floor(Math.random() * 16)];
			}
			return color;
		}

		let shouldHighlight = true;
		if (typeof $$sharedHelpers.highlightElement.highlightedElement !== 'undefined') {
			const prevEl = $$sharedHelpers.highlightElement.highlightedElement;
			if (prevEl !== el) {
				prevEl.style.outline = '';
				prevEl.style.backgroundColor = '';
			} else {
				shouldHighlight = false;
			}
		}
		if (shouldHighlight) {
			$$sharedHelpers.highlightElement.highlightedElement = el;
			const color = getRandomColor();
			el.style.outline = color + ' solid 1px';
			el.style.backgroundColor = color + '45';
		}
		return shouldHighlight;
	};


	/* Get element by point (x, y) in page's coordinate */
	// https://developer.mozilla.org/en-US/docs/Web/API/DocumentOrShadowRoot/elementFromPoint
	$$sharedHelpers.elementFromPoint = function (x, y) {
		return document.elementFromPoint(x, y);
	};


	/**
	 * Get the rect of a DOM element.
	 * @param {HTMLElement} el An element.
	 * @returns {Array.<Number>} The rect of the element in page's coordinate.
	 */
	$$sharedHelpers.getElementRect = function (el) {
		const
			boundingRect = el.getBoundingClientRect(),
			body = document.body || document.getElementsByTagName("body")[0],
			clientTop = document.documentElement.clientTop || body.clientTop || 0,
			clientLeft = document.documentElement.clientLeft || body.clientLeft || 0,
			scrollTop = (window.pageYOffset || document.documentElement.scrollTop || body.scrollTop),
			scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || body.scrollLeft);
		return [
			boundingRect.left + scrollLeft - clientLeft,
			boundingRect.top + scrollTop - clientTop,
			boundingRect.width,
			boundingRect.height
		];
	};


	/**
	 * Get the bounding client rect of a DOM element.
	 * @param {HTMLElement} el An element.
	 * @returns {Array.<Number>} The rect of the element in window's coordinate.
	 */
	$$sharedHelpers.getElementBoundingClientRect = function (el) {
		if (el === null) { return null; }
		// https://developer.mozilla.org/en-US/docs/Web/API/Element/getBoundingClientRect
		const rect = el.getBoundingClientRect();
		return [rect.left, rect.top, rect.width, rect.height];
	};


	/* Get element by selector */
	// https://developer.mozilla.org/en-US/docs/Web/API/Document/querySelector
	$$sharedHelpers.querySelector = function $$querySelector(selectors) {
		return document.querySelector(selectors);
	};


	/**
	 * Get a common selector of a DOM element.
	 * @param {HTMLElement} el An element.
	 * @returns {String} The common selector of the element.
	 */
	$$sharedHelpers.getElementSelector = function (el) {
		if (el === null) { return null; }
		const stack = [];
		while (el.parentNode != null) {
			let sibCount = 0;
			let sibIndex = 0;
			for (let i = 0; i < el.parentNode.childNodes.length; i++) {
				const sib = el.parentNode.childNodes[i];
				if (sib.nodeName === el.nodeName) {
					if (sib === el) {
						sibIndex = sibCount;
					}
					sibCount++;
				}
			}
			if (el.hasAttribute('id') && el.id !== '') {
				stack.unshift(el.nodeName.toLowerCase() + '#' + el.id);
			} else if (sibCount > 1) {
				stack.unshift(el.nodeName.toLowerCase() + ':nth-of-type(' + (sibIndex + 1) + ')');
			} else {
				stack.unshift(el.nodeName.toLowerCase());
			}
			el = el.parentNode;
		}
		return stack.slice(1).join(' > '); // removes the html element
	};

	if ($$matchingRequest !== null && typeof $$matchingRequest == 'object') {
		// responder checks were made in native layer

		// scheme dismatch
		if (typeof $$matchingRequest.scheme == 'string' && window.location.protocol != $$matchingRequest.scheme + ":") {
            console.debug("matching request test failed: scheme dismatch, '" + $$matchingRequest.scheme + ":" + "' excepted, got '" + window.location.protocol + "'");
			return undefined;
		}
		// host dismatch
		if (typeof $$matchingRequest.host == 'string' && window.location.host != $$matchingRequest.host) {
            console.debug("matching request test failed: host dismatch, '" + $$matchingRequest.host + "' excepted, got '" + window.location.host + "'");
			return undefined;
		}
		// path dismatch
		if (typeof $$matchingRequest.path == 'string' && window.location.pathname != $$matchingRequest.path) {
            console.debug("matching request test failed: path dismatch, '" + $$matchingRequest.path + "' excepted, got '" + window.location.pathname + "'");
			return undefined;
		}
		// href dismatch
		if (typeof $$matchingRequest.absoluteString == 'string' && window.location.href != $$matchingRequest.absoluteString) {
            console.debug("matching request test failed: absoluteString dismatch, '" + $$matchingRequest.absoluteString + "' excepted, got '" + window.location.href + "'");
            return undefined;
		}
		// regex of href dismatch
		if (typeof $$matchingRequest.url == 'string') {
			const regex = new RegExp($$matchingRequest.url);
			if (!regex.test(window.location.href)) {
                console.debug("matching request test failed: url dismatch, '" + $$matchingRequest.url + "' excepted, got '" + window.location.href + "'");
				return undefined;
			}
		}
	}

    // Just do it!
    console.debug("payload function injected at '" + window.location.href + "'");
    return $$payloadFunction($$sharedHelpers);
})();
