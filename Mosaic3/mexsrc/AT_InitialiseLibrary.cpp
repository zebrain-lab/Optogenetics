/*==========================================================
 * MATLAB wrapper to the ANDOR Mosaic SDK 3 
 *
 * What the function does
 *
 * The calling syntax is:
 *
 *		lhs = name_function(rhs1, rhs2)
 *
 * This is a MEX-file for MATLAB.
 * Martin Privat
 * Dec 2019
 *
 *========================================================*/

#include "mex.h"
#include "atcore.h"

/* The gateway function */
void mexFunction( int nlhs, mxArray *plhs[],
                  int nrhs, const mxArray *prhs[])
{

    // define arguments to the C function with the right type
    int ret;
    
    // check for proper number of arguments
    if(nrhs!=0) {
        mexErrMsgIdAndTxt("Optogenetics:AT_InitialiseLibrary:InvalidNumInput","Need no input arguments.");
    }
    if(nlhs!=0) {
        mexErrMsgIdAndTxt("Optogenetics:AT_InitialiseLibrary:InvalidNumOutput","Need no output arguments.");
    }
    
    // make sure that input argument have the right type
    
    // get the value of the inputs
    
    // create the output 
    
    // call the lib function
    ret = AT_InitialiseLibrary();
    if (ret != 0) {
         mexWarnMsgIdAndTxt("Optogenetics:AT_InitialiseLibrary:ReturnFailure","Library returned error %d",ret);
    }
}
