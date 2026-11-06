#ifndef _HWS_CONVERT_H_
#define _HWS_CONVERT_H_

#include "hws_scale.h"	/* BYTE, DWORD, memcpy */

/* the same type as hws.h */
typedef unsigned char BOOL;

void VideoRotate90deg(BYTE *pSrc, BYTE *pOut, int in_w, int in_h, int out_w, int out_h);
void FillNV12ToYUY2(BYTE *pSrc, BYTE *pOut, int nw, int nh, int interlace);
void SetDeInterlace(BYTE *pSrc, BYTE *pOut, int nw, int nh, int interlace);
void FillYUU2(BYTE *pSrc, BYTE *pOut, int nw, int nh, int interlace);

#endif
