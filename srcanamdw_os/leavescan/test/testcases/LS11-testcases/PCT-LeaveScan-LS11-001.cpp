//desc: test LCleanedup is used to declare a common data member of a common class
//option:
//date:2008-8-20 13:51:31
//author:pingorliu
//type: CT

class temp
{
	private:
                LCleanedupPtr<CBaz> member; //check:LCleanedup,class,data,member
};
