//desc:test multiple static leave function call of LS1
//option:
//date:2008-8-12 15:58:1
//author:pingorliu
//type: CT

void func()
{
	CL::CLL::fooL(); //check:func,leave
}
