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
//desc: test LCleanedup class used in LC overload function for LS16
//option:
//date:2008-8-21 15:19:15
//author:pingorliu
//type: CT

void funcLC()
{
}
void funcLC(TInt x)
{
LCleanedupHandle<RBar> bar; //check:suffixed,LCleanedup
}

