/*
 * CPU conversions for the HD family (hws_card_hd): YV12 or NV12 to YUYV,
 * deinterlacing, and 90-degree rotation. Moved out of hws_video.c unchanged;
 * hws_render_frame() is the caller.
 */
#include "hws_convert.h"

void VideoRotate90deg(BYTE *pSrc,BYTE *pOut,int in_w,int in_h,int out_w,int out_h)

{
	int x,y;
	BYTE*pSrcBuf;
	BYTE*pDestBuf;
	BYTE *pSrcData;
	BYTE *pDestData;
	pSrcBuf = pSrc;
	pDestBuf = pOut;
	//DbgPrint("[MV]VideoRotate90deg %dX%d->%dX%d\n",in_w,in_h,out_w,out_h);
	for(y=0;y<in_h;y++)
	{
		pSrcData = pSrcBuf;
		pDestData = pDestBuf;
		for(x=0;x<in_w/2;x++)
		{
			if((y%2) ==0)
			{
				pDestData[0]= pSrcData[0];
				pDestData[1]= pSrcData[1];
				pDestData[out_w*2+0]= pSrcData[2];
				pDestData[out_w*2+1]= pSrcData[1];
			}
			else
			{
				pDestData[0]= pSrcData[0];
				pDestData[1]= pSrcData[3];
				pDestData[out_w*2+0]= pSrcData[2];
				pDestData[out_w*2+1]= pSrcData[3];
			}
			pDestData +=out_w*4;
			pSrcData +=4;

		}
		pSrcBuf += in_w*2;
		pDestBuf += 2;

	}


}

void FillNV12ToYUY2(BYTE *pSrc,BYTE *pOut, int nw,int nh,int interlace)
{
	BYTE *pVideoMem = pOut ;// g_pD1TempBuffer;
	//DWORD dwDstPitch = nw;
	DWORD dwSrcPitch;
	DWORD dwPacket;
	BYTE *pSrc1;
	BYTE *pDstYUV = (BYTE *)pVideoMem;
	BYTE *pNextLineSrc1;
	DWORD dwJ;
	BYTE bLineSel=0;
	BOOL bUVSel;
	DWORD dwI;
	dwSrcPitch = nw*12/8;
	dwPacket = dwSrcPitch/24;

	pSrc1  = (BYTE *)pSrc;
	pDstYUV = (BYTE *)pVideoMem;

	if(interlace ==0)
	{
		for(dwI=0; dwI <nh; dwI++)
		{
			switch(bLineSel)
			{
				case 0:
				{
					bUVSel =0;
					pNextLineSrc1 = (BYTE *)pSrc1+dwSrcPitch+nw; //  line2
					for( dwJ=0; dwJ<dwPacket; dwJ++)
					{

						//-----------y0 ~y3
						pDstYUV[0] = pSrc1[0];
						pDstYUV[2] = pSrc1[1];
						pDstYUV[4] = pSrc1[2];
						pDstYUV[6] = pSrc1[3];
						//y4~y7
						pDstYUV[8]  =  pSrc1[8];
						pDstYUV[10] =  pSrc1[9];
						pDstYUV[12] =  pSrc1[10];
						pDstYUV[14] =  pSrc1[11];
						//----y8~y11
						pDstYUV[16]= pSrc1[12];
						pDstYUV[18]= pSrc1[13];
						pDstYUV[20] = pSrc1[14];
						pDstYUV[22] = pSrc1[15];
						//y12~y15
						pDstYUV[24] =  pSrc1[20];
						pDstYUV[26] =  pSrc1[21];
						pDstYUV[28] =  pSrc1[22];
						pDstYUV[30] =  pSrc1[23];

						if(bUVSel)
						{
							pDstYUV[3] =pSrc1[4];
							pDstYUV[7] =pSrc1[5];
							pDstYUV[11] =pSrc1[6];
							pDstYUV[15] =pSrc1[7];

							pDstYUV[19] =pSrc1[16];
							pDstYUV[23] =pSrc1[17];
							pDstYUV[27] =pSrc1[18];
							pDstYUV[31] =pSrc1[19];


							pDstYUV[1] =pNextLineSrc1[4];
							pDstYUV[5] =pNextLineSrc1[5];
							pDstYUV[9] =pNextLineSrc1[6];
							pDstYUV[13] =pNextLineSrc1[7];

							pDstYUV[17] =pNextLineSrc1[16];
							pDstYUV[21] =pNextLineSrc1[17];
							pDstYUV[25] =pNextLineSrc1[18];
							pDstYUV[29] =pNextLineSrc1[19];

						}
						else
						{

							pDstYUV[3]  = pNextLineSrc1[4];
							pDstYUV[7]  = pNextLineSrc1[5];
							pDstYUV[11]  = pNextLineSrc1[6];
							pDstYUV[15] = pNextLineSrc1[7];

							pDstYUV[19]  = pNextLineSrc1[16];
							pDstYUV[23]  = pNextLineSrc1[17];
							pDstYUV[27]  = pNextLineSrc1[18];
							pDstYUV[31] =  pNextLineSrc1[19];


							pDstYUV[1] =pSrc1[4];
							pDstYUV[5] =pSrc1[5];
							pDstYUV[9] =pSrc1[6];
							pDstYUV[13] =pSrc1[7];

							pDstYUV[17] =pSrc1[16];
							pDstYUV[21] =pSrc1[17];
							pDstYUV[25] =pSrc1[18];
							pDstYUV[29] =pSrc1[19];

						}
						pSrc1+=24;
						pNextLineSrc1 +=24;
						pDstYUV+=32;
					}
					break;
				}
				case 1:
				{
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					//-----modify the curr line
					for( dwJ=0; dwJ<nw; dwJ++)
					{
						pDstYUV[0] = pSrc1[0];
						pDstYUV +=2;
						pSrc1 ++;
					}

					break;
				}
				case 2:
				{
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					//-----modify the curr line
					for( dwJ=0; dwJ<dwPacket; dwJ++)
					{
						//-----------y0 ~y3
						pDstYUV[0] = pSrc1[0];
						pDstYUV[2] = pSrc1[1];
						pDstYUV[4] = pSrc1[2];
						pDstYUV[6] = pSrc1[3];
						//y4~y7
						pDstYUV[8]  =  pSrc1[8];
						pDstYUV[10] =  pSrc1[9];
						pDstYUV[12] =  pSrc1[10];
						pDstYUV[14] =  pSrc1[11];
						//----y8~y11
						pDstYUV[16]= pSrc1[12];
						pDstYUV[18]= pSrc1[13];
						pDstYUV[20] = pSrc1[14];
						pDstYUV[22] = pSrc1[15];
						//y12~y15
						pDstYUV[24] =  pSrc1[20];
						pDstYUV[26] =  pSrc1[21];
						pDstYUV[28] =  pSrc1[22];
						pDstYUV[30] =  pSrc1[23];
						pDstYUV+=32;
						pSrc1+=24;
					}
					break;
				}
				case 3:
				{
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					//-----modify the curr line
					for( dwJ=0; dwJ<nw; dwJ++)
					{
						pDstYUV[0] = pSrc1[0];
						pDstYUV +=2;
						pSrc1 ++;
					}
					break;
				}

			}
			bLineSel ++;
			if(bLineSel>=4)
			{
				bLineSel =0;
			}
		}
	}
	else
	{
		//DbgPrint("nh");
		nh= nh/2;
		for( dwI=0; dwI <nh; dwI++)
		{
			switch(bLineSel)
			{
				case 0:
				{
					bUVSel =0;
					pNextLineSrc1 = (BYTE *)pSrc1+dwSrcPitch+nw; //  line2
					for( dwJ=0; dwJ<dwPacket; dwJ++)
					{

						//-----------y0 ~y3
						pDstYUV[0] = pSrc1[0];
						pDstYUV[2] = pSrc1[1];
						pDstYUV[4] = pSrc1[2];
						pDstYUV[6] = pSrc1[3];
						//y4~y7
						pDstYUV[8]  =  pSrc1[8];
						pDstYUV[10] =  pSrc1[9];
						pDstYUV[12] =  pSrc1[10];
						pDstYUV[14] =  pSrc1[11];
						//----y8~y11
						pDstYUV[16]= pSrc1[12];
						pDstYUV[18]= pSrc1[13];
						pDstYUV[20] = pSrc1[14];
						pDstYUV[22] = pSrc1[15];
						//y12~y15
						pDstYUV[24] =  pSrc1[20];
						pDstYUV[26] =  pSrc1[21];
						pDstYUV[28] =  pSrc1[22];
						pDstYUV[30] =  pSrc1[23];

						if(bUVSel)
						{
							pDstYUV[3] =pSrc1[4];
							pDstYUV[7] =pSrc1[5];
							pDstYUV[11] =pSrc1[6];
							pDstYUV[15] =pSrc1[7];

							pDstYUV[19] =pSrc1[16];
							pDstYUV[23] =pSrc1[17];
							pDstYUV[27] =pSrc1[18];
							pDstYUV[31] =pSrc1[19];


							pDstYUV[1] =pNextLineSrc1[4];
							pDstYUV[5] =pNextLineSrc1[5];
							pDstYUV[9] =pNextLineSrc1[6];
							pDstYUV[13] =pNextLineSrc1[7];

							pDstYUV[17] =pNextLineSrc1[16];
							pDstYUV[21] =pNextLineSrc1[17];
							pDstYUV[25] =pNextLineSrc1[18];
							pDstYUV[29] =pNextLineSrc1[19];

						}
						else
						{

							pDstYUV[3]  = pNextLineSrc1[4];
							pDstYUV[7]  = pNextLineSrc1[5];
							pDstYUV[11]  = pNextLineSrc1[6];
							pDstYUV[15] = pNextLineSrc1[7];

							pDstYUV[19]  = pNextLineSrc1[16];
							pDstYUV[23]  = pNextLineSrc1[17];
							pDstYUV[27]  = pNextLineSrc1[18];
							pDstYUV[31] =  pNextLineSrc1[19];


							pDstYUV[1] =pSrc1[4];
							pDstYUV[5] =pSrc1[5];
							pDstYUV[9] =pSrc1[6];
							pDstYUV[13] =pSrc1[7];

							pDstYUV[17] =pSrc1[16];
							pDstYUV[21] =pSrc1[17];
							pDstYUV[25] =pSrc1[18];
							pDstYUV[29] =pSrc1[19];

						}
						pSrc1+=24;
						pNextLineSrc1 +=24;
						pDstYUV+=32;
					}
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					pDstYUV = pDstYUV+ nw*2;
					break;
				}
				case 1:
				{
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					//-----modify the curr line
					for( dwJ=0; dwJ<nw; dwJ++)
					{
						pDstYUV[0] = pSrc1[0];
						pDstYUV +=2;
						pSrc1 ++;
					}
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					pDstYUV = pDstYUV+ nw*2;
					break;
				}
				case 2:
				{
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					//-----modify the curr line
					for( dwJ=0; dwJ<dwPacket; dwJ++)
					{
						//-----------y0 ~y3
						pDstYUV[0] = pSrc1[0];
						pDstYUV[2] = pSrc1[1];
						pDstYUV[4] = pSrc1[2];
						pDstYUV[6] = pSrc1[3];
						//y4~y7
						pDstYUV[8]  =  pSrc1[8];
						pDstYUV[10] =  pSrc1[9];
						pDstYUV[12] =  pSrc1[10];
						pDstYUV[14] =  pSrc1[11];
						//----y8~y11
						pDstYUV[16]= pSrc1[12];
						pDstYUV[18]= pSrc1[13];
						pDstYUV[20] = pSrc1[14];
						pDstYUV[22] = pSrc1[15];
						//y12~y15
						pDstYUV[24] =  pSrc1[20];
						pDstYUV[26] =  pSrc1[21];
						pDstYUV[28] =  pSrc1[22];
						pDstYUV[30] =  pSrc1[23];
						pDstYUV+=32;
						pSrc1+=24;
					}
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					pDstYUV = pDstYUV+ nw*2;
					break;
				}
				case 3:
				{
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					//-----modify the curr line
					for( dwJ=0; dwJ<nw; dwJ++)
					{
						pDstYUV[0] = pSrc1[0];
						pDstYUV +=2;
						pSrc1 ++;
					}
					memcpy(pDstYUV,pDstYUV-(nw*2),nw*2); // copy up line
					pDstYUV = pDstYUV+ nw*2;
					break;
				}

			}
			bLineSel ++;
			if(bLineSel>=4)
			{
				bLineSel =0;
			}
		}
	}
}

void SetDeInterlace(BYTE *pSrc,BYTE *pOut, int nw,int nh,int interlace)
{
	int dwSrcPitch = nw*2;
	int h;
	//DbgPrint("[MV]SetDeInterlace W=%d H=%d interlace=%d \n",nw,nh,interlace);
	if(interlace==0)
	{
		memcpy(pOut,pSrc,nw*nh*2);
	}
	else
	{
		if(nh>=1080)
		{
			nh = nh/2;
		}
		for( h=0; h <nh; h++)
		{
			memcpy(pOut,pSrc,dwSrcPitch);
			pOut += dwSrcPitch;
			memcpy(pOut,pSrc,dwSrcPitch);
			pSrc += dwSrcPitch;
			pOut += dwSrcPitch;
		}
	}

}

void FillYUU2(BYTE *pSrc,BYTE *pOut, int nw,int nh,int interlace)
{
	BYTE *pVideoMem = pOut ;// g_pD1TempBuffer;
	//	DWORD dwDstPitch = nw;
	DWORD dwSrcPitch;
	DWORD dwI,dwJ;
	DWORD dwPacket;
	BYTE *pSrc1  = (BYTE *)pSrc;
	BYTE *pDstYUV = (BYTE *)pVideoMem;
	BYTE *pNextLineSrc1;
	BOOL bUVSel;

	dwSrcPitch = nw*12/8;
	dwPacket = dwSrcPitch/24;
	pNextLineSrc1 = (BYTE *)pSrc1+dwSrcPitch;
	if(interlace ==0)
	{
		for( dwI=0; dwI <nh; dwI++)
		{
			bUVSel = (dwI&0x1);
			for( dwJ=0; dwJ<dwPacket; dwJ++)
			{
				//-----------y0 ~y3
				pDstYUV[0] = pSrc1[0];
				pDstYUV[2] = pSrc1[1];
				pDstYUV[4] = pSrc1[2];
				pDstYUV[6] = pSrc1[3];
				//y4~y7
				pDstYUV[8]  =  pSrc1[8];
				pDstYUV[10] =  pSrc1[9];
				pDstYUV[12] =  pSrc1[10];
				pDstYUV[14] =  pSrc1[11];
				//----y8~y11
				pDstYUV[16]= pSrc1[12];
				pDstYUV[18]= pSrc1[13];
				pDstYUV[20] = pSrc1[14];
				pDstYUV[22] = pSrc1[15];
				//y12~y15
				pDstYUV[24] =  pSrc1[20];
				pDstYUV[26] =  pSrc1[21];
				pDstYUV[28] =  pSrc1[22];
				pDstYUV[30] =  pSrc1[23];

				if(bUVSel)
				{
					pDstYUV[3] =pSrc1[4];
					pDstYUV[7] =pSrc1[5];
					pDstYUV[11] =pSrc1[6];
					pDstYUV[15] =pSrc1[7];

					pDstYUV[19] =pSrc1[16];
					pDstYUV[23] =pSrc1[17];
					pDstYUV[27] =pSrc1[18];
					pDstYUV[31] =pSrc1[19];


					pDstYUV[1] =pNextLineSrc1[4];
					pDstYUV[5] =pNextLineSrc1[5];
					pDstYUV[9] =pNextLineSrc1[6];
					pDstYUV[13] =pNextLineSrc1[7];

					pDstYUV[17] =pNextLineSrc1[16];
					pDstYUV[21] =pNextLineSrc1[17];
					pDstYUV[25] =pNextLineSrc1[18];
					pDstYUV[29] =pNextLineSrc1[19];

				}
				else
				{

					pDstYUV[3]  = pNextLineSrc1[4];
					pDstYUV[7]  = pNextLineSrc1[5];
					pDstYUV[11]  = pNextLineSrc1[6];
					pDstYUV[15] = pNextLineSrc1[7];

					pDstYUV[19]  = pNextLineSrc1[16];
					pDstYUV[23]  = pNextLineSrc1[17];
					pDstYUV[27]  = pNextLineSrc1[18];
					pDstYUV[31] =  pNextLineSrc1[19];


					pDstYUV[1] =pSrc1[4];
					pDstYUV[5] =pSrc1[5];
					pDstYUV[9] =pSrc1[6];
					pDstYUV[13] =pSrc1[7];

					pDstYUV[17] =pSrc1[16];
					pDstYUV[21] =pSrc1[17];
					pDstYUV[25] =pSrc1[18];
					pDstYUV[29] =pSrc1[19];

				}

				pSrc1+=24;
				pNextLineSrc1 +=24;
				pDstYUV+=32;

			}
		}
		//--------------------------------
		pDstYUV -= 1*nw*2;
		for( dwI=0; dwI <1; dwI++)
		{
			for(  dwJ=0; dwJ<nw; dwJ++)
			{
				pDstYUV[0] = 0x10;
				pDstYUV[1] = 0x80;
				pDstYUV +=2;
			}
		}

		//---------------------------------
	}
	else
	{
		for( dwI=0; dwI <(nh/2); dwI++)
		{
			bUVSel = (dwI&0x1);
			for( dwJ=0; dwJ<dwPacket; dwJ++)
			{
				//-----------y0 ~y3
				pDstYUV[0] = pSrc1[0];
				pDstYUV[2] = pSrc1[1];
				pDstYUV[4] = pSrc1[2];
				pDstYUV[6] = pSrc1[3];
				//y4~y7
				pDstYUV[8]  =  pSrc1[8];
				pDstYUV[10] =  pSrc1[9];
				pDstYUV[12] =  pSrc1[10];
				pDstYUV[14] =  pSrc1[11];
				//----y8~y11
				pDstYUV[16]= pSrc1[12];
				pDstYUV[18]= pSrc1[13];
				pDstYUV[20] = pSrc1[14];
				pDstYUV[22] = pSrc1[15];
				//y12~y15
				pDstYUV[24] =  pSrc1[20];
				pDstYUV[26] =  pSrc1[21];
				pDstYUV[28] =  pSrc1[22];
				pDstYUV[30] =  pSrc1[23];

				if(bUVSel)
				{
					pDstYUV[3] =pSrc1[4];
					pDstYUV[7] =pSrc1[5];
					pDstYUV[11] =pSrc1[6];
					pDstYUV[15] =pSrc1[7];

					pDstYUV[19] =pSrc1[16];
					pDstYUV[23] =pSrc1[17];
					pDstYUV[27] =pSrc1[18];
					pDstYUV[31] =pSrc1[19];


					pDstYUV[1] =pNextLineSrc1[4];
					pDstYUV[5] =pNextLineSrc1[5];
					pDstYUV[9] =pNextLineSrc1[6];
					pDstYUV[13] =pNextLineSrc1[7];

					pDstYUV[17] =pNextLineSrc1[16];
					pDstYUV[21] =pNextLineSrc1[17];
					pDstYUV[25] =pNextLineSrc1[18];
					pDstYUV[29] =pNextLineSrc1[19];

				}
				else
				{

					pDstYUV[3]  = pNextLineSrc1[4];
					pDstYUV[7]  = pNextLineSrc1[5];
					pDstYUV[11]  = pNextLineSrc1[6];
					pDstYUV[15] = pNextLineSrc1[7];

					pDstYUV[19]  = pNextLineSrc1[16];
					pDstYUV[23]  = pNextLineSrc1[17];
					pDstYUV[27]  = pNextLineSrc1[18];
					pDstYUV[31] =  pNextLineSrc1[19];


					pDstYUV[1] =pSrc1[4];
					pDstYUV[5] =pSrc1[5];
					pDstYUV[9] =pSrc1[6];
					pDstYUV[13] =pSrc1[7];

					pDstYUV[17] =pSrc1[16];
					pDstYUV[21] =pSrc1[17];
					pDstYUV[25] =pSrc1[18];
					pDstYUV[29] =pSrc1[19];

				}

				pSrc1+=24;
				pNextLineSrc1 +=24;
				pDstYUV+=32;

			}
			//------------------------------
			memcpy(pDstYUV,(pDstYUV-nw*2),nw*2);
			pDstYUV = pDstYUV+ nw*2;
			//-----------------------------------
		}
		//--------------------------------
		pDstYUV -= 2*nw*2;
		for( dwI=0; dwI <2; dwI++)
		{
			for(  dwJ=0; dwJ<nw; dwJ++)
			{
				pDstYUV[0] = 0x10;
				pDstYUV[1] = 0x80;
				pDstYUV +=2;
			}
		}
		//---------------------------------

	}

}
