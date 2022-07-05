/** Copyright (c) 2011 by Robert G. Jakabosky <bobby@sharedrealm.com>
 *  
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *  
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
**/

#include "poller.h"
#include <memory.h>
#include <assert.h>
#include <memory.h>
#include <stdlib.h>

#define FREE_ITEM_EVENTS_TAG ((short)0xFFFF)

#define ITEM_TO_INDEX(items, item) (item - (items))

static int poller_resize_items(ZMQ_Poller *poller, int len) {
	int old_len = poller->len;

	/* make sure new length is atleast as large as items count. */
	len = (old_len <= len) ? len : old_len;

	/* if the new length is the same as the old length, then don't try to resize. */
	if(old_len == len) return len;

	poller->items = (zmq_pollitem_t *)realloc(poller->items, len * sizeof(zmq_pollitem_t));
	poller->len = len;
	if(len > old_len) {
		/* clear new space. */
		memset(&(poller->items[old_len]), 0, (len - old_len) * sizeof(zmq_pollitem_t));
	}
	return len;
}

void poller_init(ZMQ_Poller *poller, int length) {
	poller->items = (zmq_pollitem_t *)calloc(length, sizeof(zmq_pollitem_t));
	poller->next = -1;
	poller->count = 0;
	poller->len = length;
	poller->free_list = -1;
}

void poller_cleanup(ZMQ_Poller *poller) {
	free(poller->items);
	poller->items = NULL;
	poller->next = -1;
	poller->count = 0;
	poller->len = 0;
	poller->free_list = -1;
}

int poller_find_sock_item(ZMQ_Poller *poller, ZMQ_Socket *sock) {
	zmq_pollitem_t *items;
	int count;
	int n;

	/* find ZMQ_Socket */
	items = poller->items;
	count = poller->count;
	for(n=0; n < count; n++) {
		if(items[n].socket == sock) return n;
	}
	/* not found. */
	return -1;
}

int poller_find_fd_item(ZMQ_Poller *poller, socket_t fd) {
	zmq_pollitem_t *items;
	int count;
	int n;

	/* find fd */
	items = poller->items;
	count = poller->count;
	for(n=0; n < count; n++) {
		if(items[n].fd == fd) return n;
	}
	/* not found. */
	return -1;
}

static int poller_compact_items(ZMQ_Poller *poller);

void poller_remove_item(ZMQ_Poller *poller, int idx) {
	zmq_pollitem_t *items;
	int free_list;
	int count;

	count = poller->count;
	/* no item to remove. */
	if(idx >= count || count == 0) return;

	items = poller->items;
	free_list = poller->free_list;

	/* link new free slot to head of free list. */
	if(free_list >= 0 && free_list < count) {
		/* use socket pointer for free list's 'next' field. */
		items[idx].socket = &(items[free_list]);
	} else {
		/* free list is empty mark poller slot as the end. */
		items[idx].socket = NULL;
	}
	poller->free_list = idx;
	/* mark poller slot as a free slot. */
	items[idx].events = FREE_ITEM_EVENTS_TAG;
	/* clear old revents. */
	items[idx].revents = 0;
	poller_compact_items(poller);
}

int poller_get_free_item(ZMQ_Poller *poller) {
	zmq_pollitem_t *curr;
	zmq_pollitem_t *next;
	int count;
	int idx;

	count = poller->count;
	idx = poller->free_list;
	/* check for a free slot in the free list. */
	if(idx >= 0 && idx < count) {
		/* remove free slot from free list. */
		curr = &(poller->items[idx]);
		/* valid free slot. */
		assert(curr->events == FREE_ITEM_EVENTS_TAG);
		/* is poller the last free slot? */
		next = ((zmq_pollitem_t *)curr->socket);
		if(next != NULL) {
			/* set next free slot as head of free list. */
			poller->free_list = ITEM_TO_INDEX(poller->items, next);
		} else {
			/* free list is empty now. */
			poller->free_list = -1;
		}
		/* clear slot */
		memset(curr, 0, sizeof(zmq_pollitem_t));
		return idx;
	}

	idx = count;
	poller->count = ++count;
	/* make room for new item. */
	if(count >= poller->len) {
		poller_resize_items(poller, poller->len + 10);
	}
	return idx;
}

static int poller_compact_items(ZMQ_Poller *poller) {
	zmq_pollitem_t *items;
	int count;
	int old_count;
	int next;

	count = poller->count;
	/* if no free slot, then return. */
	if(poller->free_list < 0) return count;
	old_count = count;

	items = poller->items;
	next = 0;
	/* find first free slot. */
	while(next < count && items[next].events != FREE_ITEM_EVENTS_TAG) {
		++next;
	}

	/* move non-free slots into free slot. */
	count = next;
	++next;
	while(next < old_count) {
		if(items[next].events != FREE_ITEM_EVENTS_TAG) {
			/* found non-free slot, move it to the current free slot. */
			items[count] = items[next];
			++count;
		}
		++next;
	}

	/* clear old used-space */
	memset(&(items[count]), 0, ((old_count - count) * sizeof(zmq_pollitem_t)));
	poller->count = count;
	poller->free_list = -1; /* free list is now empty. */

	assert(count <= poller->len);
	return count;
}

int poller_poll(ZMQ_Poller *poller, long timeout) {
	int count;
	/* remove free slots from items list. */
	if(poller->free_list >= 0) {
		count = poller_compact_items(poller);
	} else {
		count = poller->count;
	}
	/* poll for events. */
	return zmq_poll(poller->items, count, timeout);
}

int poller_next_revents(ZMQ_Poller *poller, int *revents) {
	zmq_pollitem_t *items;
	int idx;

	idx = poller->next;
	/* do we need to poll for more events? */
	if(idx < 0) {
		return idx;
	}
	items = poller->items;
	/* find next item with pending events. */
	for(;idx >=0; --idx) {
		/* did we find a pending event? */
		if(items[idx].revents != 0) {
			*revents = items[idx].revents;
			poller->next = idx-1;
			return idx;
		}
	}
	/* processed all pending events. */
	poller->next = -1;
	*revents = 0;
	return -1;
}

