/*
* Copyright (c) 2009 Nokia Corporation and/or its subsidiary(-ies).
* All rights reserved.
* This component and the accompanying materials are made available
* under the terms of "Eclipse Public License v1.0"
* which accompanies this distribution, and is available
* at the URL "http://www.eclipse.org/legal/epl-v10.html".
*
* Initial Contributors:
* Nokia Corporation - initial contribution.
*
* Contributors:
*
* Description: 
*
*/
//desc:test User::LeaveNoMemory function call in member template function of a class for LS3
//option:
//date:2008-8-12 15:58:1
//author:pingorliu
//type: CT


class temp
{
void func(TInt x)
{
	fxx();
}
template<class T>
void func()
{
	T a;
	User::LeaveNoMemory(); //check:func,calls,Leave
}
};
