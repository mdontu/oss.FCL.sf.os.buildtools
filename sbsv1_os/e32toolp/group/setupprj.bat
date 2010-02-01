@REM Copyright (c) 2007-2009 Nokia Corporation and/or its subsidiary(-ies).
@REM All rights reserved.
@REM This component and the accompanying materials are made available
@REM under the terms of the License "Eclipse Public License v1.0"
@REM which accompanies this distribution, and is available
@REM at the URL "http://www.eclipse.org/legal/epl-v10.html".
@REM
@REM Initial Contributors:
@REM Nokia Corporation - initial contribution.
@REM 
@REM Contributors:
@REM
@REM Description:
@REM builds bld.bat files for subprojects within this component

@if exist %0.bat perl -w -x %0.bat %1 %2 %3 %4 %5
@if exist %0 perl -w -x %0 %1 %2 %3 %4 %5
@GOTO End

#!perl

use strict;
use Cwd;

my $EPOCRoot;

BEGIN {
	$EPOCRoot = $ENV{EPOCROOT};
	die "ERROR: Must set the EPOCROOT environment variable\n" if (!defined($EPOCRoot));
	$EPOCRoot =~ s-/-\\-go;	# for those working with UNIX shells
	die "ERROR: EPOCROOT must be an absolute path\n" if ($EPOCRoot !~ /^\\/);
	die "ERROR: EPOCROOT must not be a UNC path\n" if ($EPOCRoot =~ /^\\\\/);
	die "ERROR: EPOCROOT must end with a backslash\n" if ($EPOCRoot !~ /\\$/);
	die "ERROR: EPOCROOT must specify an existing directory\n" if (!-d $EPOCRoot);
}


my $EPOCToolsPath="${EPOCRoot}epoc32\\tools";

my $EPOCToolsConfigFilePath="${EPOCRoot}epoc32\\tools\\compilation_config";

my $DocsPath="${EPOCRoot}epoc32\\EngDoc\\E32toolp";

my $TemplateFilePath="${EPOCRoot}epoc32\\tools\\makefile_templates";

my $ShellFilePath="${EPOCRoot}epoc32\\tools\\shell";

my $BinFilePath="${EPOCRoot}epoc32\\tools";

if (scalar @ARGV > 1) {
	die "Too many arguments for setupprj.bat\n";
}

# only the secure platform is now supported, but keep the argument
# checking as insurance against future developments.
#
my $secure = 1;
if (scalar @ARGV == 1) {
	my $option = $ARGV[0];
	if ($option !~ /^secure$/i) {
		die "Unknown option $ARGV[0] - did you mean \"secure\"?\n";
	}
}

my $GroupDir=$0;  # $0 is this script
$GroupDir=~s-^\w:(.*)$-$1-o;  # remove drive letter
$GroupDir=~s-\/-\\-go;
unless ($GroupDir=~m-^\\-o)
	{
	# $GroupDir is relative
	my $Cwd=cwd();
	$Cwd=~s-^\w:(.*)$-$1-o;  # remove drive letter
	$Cwd=~s-\/-\\-go;
	$Cwd=~s-^\\$--o;  # make sure we don't end in a backslash
	$GroupDir="$Cwd\\$GroupDir";  # append relative group dir to absolute Cwd
	}
$GroupDir=~s-^(.*\\)[^\\]+$-$1-o; # remove filename, leaving just path
# strip the resulting path of excess occurrences of . and ..
while ($GroupDir=~s-\\\.\\-\\-go) { }
while ($GroupDir=~s-\\(?!\.{2}\\)[^\\]*\\\.{2}(?=\\)--go) { }

my $GroupToRoot=&UpToRoot($GroupDir);
chop $GroupToRoot;

my $GroupToToolsPath="$GroupToRoot$EPOCToolsPath";

my $GroupToToolsConfigFilePath="$GroupToRoot$EPOCToolsConfigFilePath";

my $GroupToDocsPath="$GroupToRoot$DocsPath";
	
my $GroupToTemplatePath="$GroupToRoot$TemplateFilePath";

my $GroupToShellPath="$GroupToRoot$ShellFilePath";

my $GroupToBinPath="$GroupToRoot$BinFilePath";

$GroupDir=~s-\\$--o;	# remove trailing backslash
chdir "$GroupDir" or die "Can't cd to $GroupDir: $!\n";

my %Files=();

# read the component
opendir E32TOOLP, ".." or die "ERROR: Can't open dir ..\n";
my $SubDir;
foreach $SubDir (grep /^[^\.]/o, map lc $_, readdir E32TOOLP) {
	if ($SubDir!~/^(group|docs|test|binutils|maksym)$/o) {
		opendir SUBDIR, "..\\$SubDir" or die "ERROR: Can't open dir \"..\\$SubDir\"\n";
		my @FileList = map lc $_, readdir SUBDIR;
		foreach my $file (grep /^[^_\.].+\.(pm|pl|bat|cmd|config|bsf|xml|cwlink|txt)$/o, @FileList) {
			$Files{$file} = "$SubDir\\$file";
		}
		if ($secure) {
			# Look for additional files whose names start with _secure_
			my @securefiles = grep /^_secure_.+\.(pm|pl|bat|cmd|config|bsf|xml|cwlink|txt)$/o, @FileList;
			foreach my $file (@securefiles) {
				my $dstfile = $file;
				$dstfile =~ s/^_secure_//;
				if (defined($Files{$dstfile})) {
					print "$dstfile: $SubDir\\$file overrides $Files{$dstfile}\n";
				}
				$Files{$dstfile} = "$SubDir\\$file";
			}
		}
	}
}

# read the compiler configuration files
my @ConfigFiles;

opendir CONFIGDIR, "..\\platform" or die "ERROR: Can't open dir \"..\\platform\"\n";
@ConfigFiles = grep /\.(mk|make)/i, readdir CONFIGDIR;

closedir CONFIGDIR;

opendir SUBDIR, "..\\Docs" or die "ERROR: Can't open dir \"..\\Docs\"\n";
my @Docs = map lc $_, readdir SUBDIR;
@Docs = grep /^[^\.].+\.(rtf|doc|changes|txt|html|htm)$/o, @Docs;
	
closedir SUBDIR;	

open TEMPLATEFILESUBDIR, "\"dir \/s \/b \/a-d ..\\..\\..\\toolsandutils\\buildsystem\\extension\" |";
my @TemplateFiles=();
my %TemplateDirs;
while (<TEMPLATEFILESUBDIR>)
	{
	next if ($_ !~ /\.(mk|meta)$/i);	
	$_ =~ s/^.*\\buildsystem\\extension\\//i;
	chomp $_;
	push @TemplateFiles, $_;
	$_ =~ /^(.*\\)/o;
	my $path = $1;
	$path =~ s/\\$//;
	$TemplateDirs{$path}=1;	
	}
close TEMPLATEFILESUBDIR;

opendir SHELLFILESUBDIR, "..\\..\\..\\toolsandutils\\buildsystem\\shell" or die "ERROR: Can't open dir \"..\\buildsystem\\shell\"\n";
my @ShellFiles = map lc $_, readdir SHELLFILESUBDIR;
@ShellFiles = grep /^[^\.].+\.(mk)$/o, @ShellFiles;
closedir SHELLFILESUBDIR;

open BINFILESUBDIR, "\"dir \/s \/b \/a-d ..\\..\\..\\toolsandutils\\buildsystem\\bin\" |";
my @BinFiles=();
my %BinDirs;
while (<BINFILESUBDIR>)
    	{
    	next if ($_ !~ /\.(exe|jar)$/i);	
    	$_ =~ s/^.*\\buildsystem\\bin\\//i;
    	chomp $_;
    	push @BinFiles, $_;
    	$_ =~ /^(.*\\)/o;
    	my $path = $1;
    	$path =~ s/\\$//;
    	$BinDirs{$path}=1;	
    	}
close BINFILESUBDIR;

my $PrintGroupDir=$GroupDir;
$PrintGroupDir=~s-\\-\\\\-go;

# Create BLD.BAT
my $OutTxt='';
&Output(
	"\@echo off\n",
	"\@goto invoke\n",
	"\n",
	"#!perl\n",
	"unless (\@ARGV==1 && \$ARGV[0]=~/^(deb|rel|clean)\$/io) {\n",
	"	die\n",
	"		\"E32TOOLP's bld.bat - usage\\n\",\n",
	"		\"BLD [param]\\n\",\n",
	"		\"where\\n\",\n",
	"		\"param = DEB or REL or CLEAN\\n\"\n",
	"	;\n",
	"}\n",
	"my \$Param=lc \$ARGV[0];\n",
	"chdir \"$PrintGroupDir\";\n",
	"print \"..\\\\binutils\\\\make -s -f e32toolp.make \$Param\\n\";\n",
	"open PIPE, \"..\\\\binutils\\\\make -s -f e32toolp.make \$Param |\" or die \"Can't invoke make: \$!\\n\";\n",
	"while (<PIPE>) {}\n",
	"close PIPE;\n",
	"\n",
	"__END__\n",
	"\n",
	":invoke\n",
	"perl -x $GroupDir\\bld.bat %1 %2\n"
);
	
my $BLDFILE='bld.bat';
print "Creating File \"$BLDFILE\"\n";
open BLDFILE,">$BLDFILE" or die "\nERROR: Can't open or create Batch file \"$BLDFILE\"\n";
print BLDFILE "$OutTxt" or die "\nERROR: Can't write output to Batch file \"$BLDFILE\"\n";
close BLDFILE or die "\nERROR: Can't close Batch file \"$BLDFILE\"\n";


# Create the make file
$OutTxt='';
&Output(
	"\n",
	"ifeq (\$(OS),Windows_NT)\n",
	"ERASE = \@erase 2>>nul\n",
	"else\n",
	"ERASE = \@erase\n",
	"endif\n",
	"\n",
	"\n",
	"$GroupToToolsPath :\n",
	"\t\@perl -w ..\\genutil\\emkdir.pl $GroupToToolsPath\n", 
	"\n",
	"$GroupToTemplatePath :\n",
	"\t\@perl -w ..\\genutil\\emkdir.pl $GroupToTemplatePath\n", 
	"\n"
);

foreach (sort keys %TemplateDirs) {
	&Output(
	"$GroupToTemplatePath\\$_ :\n",
	"\t\@perl -w ..\\genutil\\emkdir.pl $GroupToTemplatePath\\$_\n", 
	"\n"
	);
}

foreach (sort keys %BinDirs) {
 	&Output(
 	"$GroupToBinPath\\$_ :\n",
 	"\t\@perl -w ..\\genutil\\emkdir.pl $GroupToBinPath\\$_\n", 
 	"\n"
 	);
}

&Output(
	"$GroupToShellPath :\n",
	"\t\@perl -w ..\\genutil\\emkdir.pl $GroupToShellPath\n", 
	"\n",
	"$GroupToToolsConfigFilePath :\n",
	"\t\@perl -w ..\\genutil\\emkdir.pl $GroupToToolsConfigFilePath\n", 
	"\n",
	"$GroupToDocsPath :\n",
	"\t\@perl -w ..\\genutil\\emkdir.pl $GroupToDocsPath\n", 
	"\n",
	"\n",
	"deb : $GroupToToolsPath $GroupToToolsConfigFilePath $GroupToDocsPath $GroupToTemplatePath $GroupToShellPath "
);

foreach (sort keys %TemplateDirs) {
	&Output(
	"$GroupToTemplatePath\\$_ "
	);
}

foreach (sort keys %BinDirs) {
 	&Output(
 	"$GroupToBinPath\\$_ "
 	);
}

&Output("\n");

my $File;
foreach $File (keys %Files) {
	&Output(
		"\tcopy \"..\\$Files{$File}\" \"$GroupToToolsPath\\$File\" >nul\n"
	);
}

my $ConfigFile;
foreach $ConfigFile (@ConfigFiles) {
	&Output(
		"\tcopy \"..\\platform\\$ConfigFile\" \"$GroupToToolsConfigFilePath\\$ConfigFile\" >nul\n"
	);
}

foreach $File (@Docs) {
	&Output(
			"\tcopy \"..\\Docs\\$File\" \"$GroupToDocsPath\\$File\" >nul\n"
	);
}

my $tfile;
foreach $tfile (@TemplateFiles) {
	&Output(
			"\tcopy \"..\\..\\..\\toolsandutils\\buildsystem\\extension\\$tfile\" \"$GroupToTemplatePath\\$tfile\" >nul\n"
	);
}

my $bfile;
foreach $bfile (@BinFiles) {
 	&Output(
 			"\tcopy \"..\\..\\..\\toolsandutils\\buildsystem\\bin\\$bfile\" \"$GroupToBinPath\\$bfile\" >nul\n"
 	);
}

my $sfile;
foreach $sfile (@ShellFiles) {
	&Output(
			"\tcopy \"..\\..\\..\\toolsandutils\\buildsystem\\shell\\$sfile\" \"$GroupToShellPath\\$sfile\" >nul\n"
	);
}

&Output(
	"\n",
	"\n",
	"rel : $GroupToToolsPath $GroupToToolsConfigFilePath $GroupToDocsPath $GroupToTemplatePath $GroupToShellPath "
);

foreach (sort keys %TemplateDirs) {
	&Output(
	"$GroupToTemplatePath\\$_ "
	);
}

foreach (sort keys %BinDirs) {
 	&Output(
 	"$GroupToBinPath\\$_ "
 	);
}

&Output("\n");

	
foreach $File (keys %Files) {
	&Output(
		"\t.\\perlprep.bat \"..\\$Files{$File}\" \"$GroupToToolsPath\\$File\"\n"
	);
}

foreach $ConfigFile (@ConfigFiles) {
	&Output(
		"\tcopy \"..\\platform\\$ConfigFile\" \"$GroupToToolsConfigFilePath\\$ConfigFile\" >nul\n"
	);
}

foreach $File (@Docs) {
	&Output(
			"\tcopy \"..\\Docs\\$File\" \"$GroupToDocsPath\\$File\" >nul\n"
	);
}

foreach $tfile (@TemplateFiles) {
	&Output(
			"\tcopy \"..\\..\\..\\toolsandutils\\buildsystem\\extension\\$tfile\" \"$GroupToTemplatePath\\$tfile\" >nul\n"
	);
}
foreach $bfile (@BinFiles) {
 	&Output(
 			"\tcopy \"..\\..\\..\\toolsandutils\\buildsystem\\bin\\$bfile\" \"$GroupToBinPath\\$bfile\" >nul\n"
 	);
}
foreach $sfile (@ShellFiles) {
	&Output(
			"\tcopy \"..\\..\\..\\toolsandutils\\buildsystem\\shell\\$sfile\" \"$GroupToShellPath\\$sfile\" >nul\n"
	);
}
&Output(
	"\n",
	"rel deb : $GroupToToolsPath\\make.exe\n",
	"$GroupToToolsPath\\make.exe: ..\\binutils\\make.exe\n",
	"\tcopy \$\? \$\@\n"
);

&Output(
	"\n",
	"rel deb : $GroupToToolsPath\\scpp.exe\n",
	"$GroupToToolsPath\\scpp.exe: ..\\binutils\\scpp.exe\n",
	"\tcopy \$\? \$\@\n"
);


&Output(
	"\n",
	"clean :\n"
);
foreach $File (keys %Files) {
	&Output(
		"\t-\$(ERASE) \"$GroupToToolsPath\\$File\"\n"
	);
}
foreach $ConfigFile (@ConfigFiles) {
	&Output(
		"\t-\$(ERASE) \"$GroupToToolsConfigFilePath\\$ConfigFile\"\n"
	);
}
foreach $File (@Docs) {
	&Output(
			"\t-\$(ERASE) \"$GroupToDocsPath\\$File\"\n"
	);
}
foreach $tfile (@TemplateFiles) {
	&Output(
			"\t-\$(ERASE) \"$GroupToTemplatePath\\$tfile\"\n"
	);
}
foreach $bfile (@BinFiles) {
 	&Output(
 			"\t-\$(ERASE) \"$GroupToBinPath\\$bfile\"\n"
 	);
}
foreach $sfile (@ShellFiles) {
	&Output(
			"\t-\$(ERASE) \"$GroupToShellPath\\$sfile\"\n"
	);
}

my $MAKEFILE="e32toolp.make";
print "Creating File \"$MAKEFILE\"\n";
open MAKEFILE,">$MAKEFILE" or die "\nERROR: Can't open or create Batch file \"$MAKEFILE\"\n";
print MAKEFILE "$OutTxt" or die "\nERROR: Can't write output to Batch file \"$MAKEFILE\"\n";
close MAKEFILE or die "\nERROR: Can't close Batch file \"$MAKEFILE\"\n";



# this code autocreates the .rel file

my @ToolsDst = ("make.exe", "scpp.exe");
my @DocsDst = @Docs;
my @ConfigFilesDst = @ConfigFiles;
my @TemplateFilesDst = @TemplateFiles;
my @BinFilesDst = @BinFiles;
my @ShellFilesDst = @ShellFiles;

push @ToolsDst, keys %Files;

# TOOLS.REL file 

my $RELFILE="tools.rel";
print "Creating File \"$RELFILE\"\n";
open RELFILE,">$RELFILE" or die "\nERROR: Can't open or create Rel file \"$RELFILE\"\n";
print RELFILE "${EPOCRoot}epoc32\\tools\\";
print RELFILE join("\n${EPOCRoot}epoc32\\tools\\", sort @ToolsDst);
print RELFILE join("\n${EPOCRoot}epoc32\\tools\\compilation_config\\","", sort @ConfigFilesDst);
print RELFILE join("\n${EPOCRoot}epoc32\\EngDoc\\E32toolp\\","", sort @DocsDst);
close RELFILE or die "\nERROR: Can't close Rel file \"$RELFILE\"\n";

# Check MRP file - the modern equivalent of tools.rel

my $NewMRPText = "component tools_e32toolp\n";
$NewMRPText .= "# This file is generated by setupprj.bat\n\n";
$NewMRPText .= "ipr T\n";
$NewMRPText .= "ipr O  \\sf\\os\\buildtools\\sbsv1_os\\e32toolp\\binutils\n\n";
$NewMRPText .= "source \\sf\\os\\buildtools\\sbsv1_os\\e32toolp\n";
$NewMRPText .= "source \\sf\\os\\buildtools\\toolsandutils\\buildsystem\n";
$NewMRPText .= join("\nbinary \\epoc32\\tools\\", "",sort @ToolsDst);
# Don't include EngDoc files in the MRP file
$NewMRPText .= join("\nbinary \\epoc32\\tools\\compilation_config\\","", sort @ConfigFilesDst);
$NewMRPText .= join("\nbinary \\epoc32\\tools\\makefile_templates\\","", sort @TemplateFilesDst);
$NewMRPText .= join("\nbinary \\epoc32\\tools\\","", sort @BinFilesDst);
$NewMRPText .= join("\nbinary \\epoc32\\tools\\shell\\","", sort @ShellFilesDst);
$NewMRPText .= "\n\n";
$NewMRPText .= "notes_source \\component_defs\\release.src\n";

my $MRPFILE="tools_e32toolp.mrp";
open MRPFILE,"<$MRPFILE" or die "\nERROR: Can't read MRP file \"$MRPFILE\"\n";
my $OldMRPText = "";
sysread MRPFILE, $OldMRPText, 100000;	# assumes MRP file is less than 100,000 bytes
close MRPFILE or die "\nERROR: Can't close MRP file \"$MRPFILE\"\n";

if ($OldMRPText ne $NewMRPText) {
	print "REMARK: MRP file \"$MRPFILE\" differs from setupprj.bat generated content\n";
	print "Creating suggested new MRP file \"$MRPFILE.new\"\n";
	open MRPFILE,">$MRPFILE.new" or die "\nERROR: Can't open or create MRP file \"$MRPFILE.new\"\n";
	print MRPFILE $NewMRPText;
	close MRPFILE or die "\nERROR: Can't close MRP file \"$MRPFILE.new\"\n";
}


# SUBROUTINE SECTION
####################
sub Output (@) {
	my $Txt;
	foreach $Txt (@_) {
		$OutTxt.=$Txt;
	}
}

sub UpToRoot ($) {	#args: $_[0] Abs FilePath/Path
# return the path that will lead from the directory the path passed into the function
# specifies back up to the root directory
	return undef unless $_[0]=~m-^\\-o;
	my $Path=$_[0];
	my $UpP;
	while ($Path=~m-\\-go)
		{
		$UpP.="..\\";
		}
	undef $Path;
	$UpP=~s-^(.*)\.\.\\-$1-o;
	$UpP=".\\" unless $UpP;
}



__END__

:End
