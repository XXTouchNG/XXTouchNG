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

#ifndef _POLLER_H_
#define _POLLER_H_
#ifdef _WIN32
#include <winsock2.h>
typedef SOCKET socket_t;
#else
typedef int socket_t;
#endif

#include "zmq.h"

struct ZMQ_Poller {
	zmq_pollitem_t *items;
	int    next;
	int    count;
	int    free_list;
	int    len;
};

typedef struct ZMQ_Socket ZMQ_Socket;
typedef struct ZMQ_Poller ZMQ_Poller;


void poller_init           (ZMQ_Poller *poller, int length);
void poller_cleanup        (ZMQ_Poller *poller);
int  poller_find_sock_item (ZMQ_Poller *poller, ZMQ_Socket *sock);
int  poller_find_fd_item   (ZMQ_Poller *poller, socket_t fd);
void poller_remove_item    (ZMQ_Poller *poller, int idx);
int  poller_get_free_item  (ZMQ_Poller *poller);
int  poller_poll           (ZMQ_Poller *poller, long timeout);
int  poller_next_revents   (ZMQ_Poller *poller, int *revents);

#endif
