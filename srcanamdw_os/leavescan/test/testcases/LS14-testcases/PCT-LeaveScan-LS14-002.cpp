//desc:test LString is used as a parameter of a non-leaving member function of a class for LS14
//option:
//date:2008-8-21 14:10:2
//author:pingorliu
//type: CT

class temp
{
	public:
void func(LString16 x) //check:func,parameter
{
}
};
