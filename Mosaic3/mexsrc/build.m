SDK = 'C:\Program Files (x86)\Andor Mosaic 3 SDK\sdk';
srcpath = 'E:\Martin\Optogenetics\Mosaic3\mexsrc';
buildpath = 'E:\Martin\Optogenetics\Mosaic3\mexbuild';

cd(srcpath)
src = dir('*.cpp');
for f = 1:length(src)
    mex(['-I' SDK],['-L' SDK],'-latcorem.lib','-outdir',buildpath,src(f).name)
end
