// Copyright (c) 1998-2009 Nokia Corporation and/or its subsidiary(-ies).
// All rights reserved.
// This component and the accompanying materials are made available
// under the terms of the License "Eclipse Public License v1.0"
// which accompanies this distribution, and is available
// at the URL "http://www.eclipse.org/legal/epl-v10.html".
//
// Initial Contributors:
// Nokia Corporation - initial contribution.
//
// Contributors:
//
// Description:
// e32tools\petran\Szip\decode.cpp
// 
//

#include "huffman.h"
#include "panic.h"
#include <cpudefs.h>
#include "h_utl.h"
#include "farray.h"


const TInt KHuffTerminate=0x0001;
const TUint32 KBranch1=sizeof(TUint32)<<16;

TUint32* HuffmanSubTree(TUint32* aPtr,const TUint32* aValue,TUint32** aLevel)
//
// write the subtree below aPtr and return the head
//
	{
	TUint32* l=*aLevel++;
	if (l>aValue)
		{
		TUint32* sub0=HuffmanSubTree(aPtr,aValue,aLevel);	// 0-tree first
		aPtr=HuffmanSubTree(sub0,aValue-(aPtr-sub0)-1,aLevel);			// 1-tree
		TInt branch0=(TUint8*)sub0-(TUint8*)(aPtr-1);
		*--aPtr=KBranch1|branch0;
		}
	else if (l==aValue)
		{
		TUint term0=*aValue--;						// 0-term
		aPtr=HuffmanSubTree(aPtr,aValue,aLevel);			// 1-tree
		*--aPtr=KBranch1|(term0>>16);
		}
	else	// l<iNext
		{
		TUint term0=*aValue--;						// 0-term
		TUint term1=*aValue--;
		*--aPtr=(term1>>16<<16)|(term0>>16);
		}
	return aPtr;
	}

void Huffman::Decoding(const TUint32 aHuffman[],TInt aNumCodes,TUint32 aDecodeTree[],TInt aSymbolBase)
/** Create a canonical Huffman decoding tree

	This generates the huffman decoding tree used by TBitInput::HuffmanL() to read huffman
	encoded data. The input is table of code lengths, as generated by Huffman::HuffmanL()
	and must represent a valid huffman code.
	
	@param "const TUint32 aHuffman[]" The table of code lengths as generated by Huffman::HuffmanL()
	@param "TInt aNumCodes" The number of codes in the table
	@param "TUint32 aDecodeTree[]" The space for the decoding tree. This must be the same
		size as the code-length table, and can safely be the same memory
	@param "TInt aSymbolBase" the base value for the output 'symbols' from the decoding tree, by default
		this is zero.

	@panic "USER ???" If the provided code is not a valid Huffman coding

	@see IsValid()
	@see HuffmanL()
*/
	{
	if(!IsValid(aHuffman,aNumCodes))
		Panic(EHuffmanInvalidCoding);
//
	TFixedArray<TInt,KMaxCodeLength> counts;
	counts.Reset();
	TInt codes=0;
	TInt ii;
	for (ii=0;ii<aNumCodes;++ii)
		{
		TInt len=aHuffman[ii];
		aDecodeTree[ii]=len;
		if (--len>=0)
			{
			++counts[len];
			++codes;
			}
		}
//
	TFixedArray<TUint32*,KMaxCodeLength> level;
	TUint32* lit=aDecodeTree+codes;
	for (ii=0;ii<KMaxCodeLength;++ii)
		{
		level[ii]=lit;
		lit-=counts[ii];
		}
	aSymbolBase=(aSymbolBase<<17)+(KHuffTerminate<<16);
	for (ii=0;ii<aNumCodes;++ii)
		{
		TUint len=TUint8(aDecodeTree[ii]);
		if (len)
			*--level[len-1]|=(ii<<17)+aSymbolBase;
		}
	if (codes==1)	// codes==1 special case: the tree is not complete
		{
		TUint term=aDecodeTree[0]>>16;
		aDecodeTree[0]=term|(term<<16); // 0- and 1-terminate at root
		}
	else if (codes>1)
		HuffmanSubTree(aDecodeTree+codes-1,aDecodeTree+codes-1,&level[0]);
	}

// The decoding tree for the externalised code
const TUint32 HuffmanDecoding[]=
	{
	0x0004006c,
	0x00040064,
	0x0004005c,
	0x00040050,
	0x00040044,
	0x0004003c,
	0x00040034,
	0x00040021,
	0x00040023,
	0x00040025,
	0x00040027,
	0x00040029,
	0x00040014,
	0x0004000c,
	0x00040035,
	0x00390037,
	0x00330031,
	0x0004002b,
	0x002f002d,
	0x001f001d,
	0x001b0019,
	0x00040013,
	0x00170015,
	0x0004000d,
	0x0011000f,
	0x000b0009,
	0x00070003,
	0x00050001
	};

void Huffman::InternalizeL(TBitInput& aInput,TUint32 aHuffman[],TInt aNumCodes)
/** Restore a canonical huffman encoding from a bit stream

	The encoding must have been stored using Huffman::ExternalizeL(). The resulting
	code-length table can be used to create an encoding table using Huffman::Encoding()
	or a decoding tree using Huffman::Decoding().
	
	@param "TBitInput& aInput" The input stream with the encoding
	@param "TUint32 aHuffman[]" The internalized code-length table is placed here
	@param "TInt aNumCodes" The number of huffman codes in the table

	@leave "TBitInput::HuffmanL()"

	@see ExternalizeL()
*/
// See ExternalizeL for a description of the format
	{
	// initialise move-to-front list
	TFixedArray<TUint8,Huffman::KMetaCodes> list;
	for (TInt i=0;i<list.Count();++i)
		list[i]=TUint8(i);
	TInt last=0;
	// extract codes, reverse rle-0 and mtf encoding in one pass
	TUint32* p=aHuffman;
	const TUint32* end=aHuffman+aNumCodes;
	TInt rl=0;
	while (p+rl<end)
		{
		TInt c=aInput.HuffmanL(HuffmanDecoding);
		if (c<2)
			{
			// one of the zero codes used by RLE-0
			// update he run-length
			rl+=rl+c+1;
			}
		else
			{
			while (rl>0)
				{
				if (p>end)
					{
					Panic(EHuffmanCorruptFile);
					}
				*p++=last;
				--rl;
				}
			--c;
			list[0]=TUint8(last);
			last=list[c];
			HMem::Copy(&list[1],&list[0],c);
			if (p>end)
				{
				Panic(EHuffmanCorruptFile);
				}
			*p++=last;
			}
		}
	while (rl>0)
		{
		if (p>end)
			{
			Panic(EHuffmanCorruptFile);
			}
		*p++=last;
		--rl;
		}
	}

// bit-stream input class

inline TUint reverse(TUint aVal)
//
// Reverse the byte-order of a 32 bit value
// This generates optimal ARM code (4 instructions)
//
	{
	TUint v=(aVal<<16)|(aVal>>16);
	v^=aVal;
	v&=0xff00ffff;
	aVal=(aVal>>8)|(aVal<<24);
	return aVal^(v>>8);
	}

TBitInput::TBitInput()
/** Construct a bit stream input object

	Following construction the bit stream is ready for reading bits, but will
	immediately call UnderflowL() as the input buffer is empty.
*/
	:iCount(0),iRemain(0)
	{}

TBitInput::TBitInput(const TUint8* aPtr, TInt aLength, TInt aOffset)
/** Construct a bit stream input object over a buffer

	Following construction the bit stream is ready for reading bits from
	the specified buffer.

	@param "const TUint8* aPtr" The address of the buffer containing the bit stream
	@param "TInt aLength" The length of the bitstream in bits
	@param "TInt aOffset" The bit offset from the start of the buffer to the bit stream (defaults to zero)
*/
	{
	Set(aPtr,aLength,aOffset);
	}

void TBitInput::Set(const TUint8* aPtr, TInt aLength, TInt aOffset)
/** Set the memory buffer to use for input

	Bits will be read from this buffer until it is empty, at which point
	UnderflowL() will be called.
	
	@param "const TUint8* aPtr" The address of the buffer containing the bit stream
	@param "TInt aLength" The length of the bitstream in bits
	@param "TInt aOffset" The bit offset from the start of the buffer to the bit stream (defaults to zero)
*/
	{
	TUint p=(TUint)aPtr;
	p+=aOffset>>3;			// nearest byte to the specified bit offset
	aOffset&=7;				// bit offset within the byte
	const TUint32* ptr=(const TUint32*)(p&~3);	// word containing this byte
	aOffset+=(p&3)<<3;		// bit offset within the word
	if (aLength==0)
		iCount=0;
	else
		{
		// read the first few bits of the stream
		iBits=reverse(*ptr++)<<aOffset;
		aOffset=32-aOffset;
		aLength-=aOffset;
		if (aLength<0)
			aOffset+=aLength;
		iCount=aOffset;
		}
	iRemain=aLength;
	iPtr=ptr;
	}

#ifndef __HUFFMAN_MACHINE_CODED__

TUint TBitInput::ReadL()
/** Read a single bit from the input

	Return the next bit in the input stream. This will call UnderflowL() if
	there are no more bits available.

	@return The next bit in the stream

	@leave "UnderflowL()" It the bit stream is exhausted more UnderflowL is called
		to get more data
*/
	{
	TInt c=iCount;
	TUint bits=iBits;
	if (--c<0)
		return ReadL(1);
	iCount=c;
	iBits=bits<<1;
	return bits>>31;
	}

TUint TBitInput::ReadL(TInt aSize)
/** Read a multi-bit value from the input

	Return the next few bits as an unsigned integer. The last bit read is
	the least significant bit of the returned value, and the value is
	zero extended to return a 32-bit result.

	A read of zero bits will always reaturn zero.
	
	This will call UnderflowL() if there are not enough bits available.

	@param "TInt aSize" The number of bits to read

	@return The bits read from the stream

	@leave "UnderflowL()" It the bit stream is exhausted more UnderflowL is called
		to get more data
*/
	{
	if (!aSize)
		return 0;
	TUint val=0;
	TUint bits=iBits;
	iCount-=aSize;
	while (iCount<0)
		{
		// need more bits
#ifdef __CPU_X86
		// X86 does not allow shift-by-32
		if (iCount+aSize!=0)
			val|=bits>>(32-(iCount+aSize))<<(-iCount);	// scrub low order bits
#else
		val|=bits>>(32-(iCount+aSize))<<(-iCount);	// scrub low order bits
#endif
		aSize=-iCount;	// bits still required
		if (iRemain>0)
			{
			bits=reverse(*iPtr++);
			iCount+=32;
			iRemain-=32;
			if (iRemain<0)
				iCount+=iRemain;
			}
		else
			{
			UnderflowL();
			bits=iBits;
			iCount-=aSize;
			}
		}
#ifdef __CPU_X86
	// X86 does not allow shift-by-32
	iBits=aSize==32?0:bits<<aSize;
#else
	iBits=bits<<aSize;
#endif
	return val|(bits>>(32-aSize));
	}

TUint TBitInput::HuffmanL(const TUint32* aTree)
/** Read and decode a Huffman Code

	Interpret the next bits in the input as a Huffman code in the specified
	decoding. The decoding tree should be the output from Huffman::Decoding().

	@param "const TUint32* aTree" The huffman decoding tree

	@return The symbol that was decoded
	
	@leave "UnderflowL()" It the bit stream is exhausted more UnderflowL is called
		to get more data
*/
	{
	TUint huff=0;
	do
		{
		aTree=PtrAdd(aTree,huff>>16);
		huff=*aTree;
		if (ReadL()==0)
			huff<<=16;
		} while ((huff&0x10000u)==0);
	return huff>>17;
	}

#endif

void TBitInput::UnderflowL()
/** Handle an empty input buffer

	This virtual function is called when the input buffer is empty and
	more bits are required. It should reset the input buffer with more
	data using Set().

	A derived class can replace this to read the data from a file
	(for example) before reseting the input buffer.

	@leave "KErrUnderflow" The default implementation leaves
*/
	{
	Panic(EHuffmanBufferOverflow);
	}

