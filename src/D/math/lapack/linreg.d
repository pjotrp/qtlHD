/*
 * linreg: linear regression utility functions
 *
 * dgels uses QR, but X matrix must be full rank
 * dgelsy allows X matrix < full rank
 *
 * Lapack benchmarks at http://www.netlib.org/lapack/lug/node71.html
 *     dgelsy indistinguishable from dgels
 *     dgelsd (SVD) 3-5x slower; dgelss (used in R/qtl if X < full rank) 7-34x slower
 *
 * The R function lm() using dqrls, which is Linpack rather than Lapack
 */

module math.lapack.linreg;

import std.algorithm;
import std.math;
import std.range;
import std.c.stdio;
import std.stdio;
import std.string;
import std.conv;

import std.c.stdlib;

extern(C) {
  alias float f_float;
  alias double f_double;
  alias int f_int;
  alias char f_char;
}

version(Windows){
  private import std.loader;
  private import arch.windows;
  private import qtl.plugins.renv.libload;

  extern (C) void function(f_char *trans, f_int *m, f_int *n, f_int *nrhs, f_double *A, f_int *lda,
                           f_double *B, f_int *ldb, f_double *work, f_int *lwork, f_int *info) dgels_;

  extern (C) void function(f_int *m, f_int *n, f_int *nrhs, f_double *A, f_int *lda,
                           f_double *B, f_int *ldb, f_int *jpvt, f_double *rcond,
                           f_int *rank, f_double *work, f_int *lwork, f_int *info) dgelsy_;

  extern (C) void function(f_char *transa, f_char *transb, f_int *m, f_int *n, f_int *k,
                           f_double *alpha, f_double *a, f_int *lda, f_double *b, f_int *ldb,
                           f_double *beta, f_double *c, f_int *ldc) dgemm_;

  static this(){
    HXModule lib_lapack = load_library("Rlapack");
    load_function(dgels_)(lib_lapack,"dgels_");
    load_function(dgelsy_)(lib_lapack,"dgelsy_");
    writeln("Loaded Rlapack functionality");


    HXModule lib_blas = load_library("Rblas");
    load_function(dgemm_)(lib_blas,"dgemm_");
    writeln("Loaded Rblas functionality");
  }

}else{
  pragma(lib, "blas");
  pragma(lib, "lapack");

  // Two Lapack routines for linear regression
  // dgels requires covariate matrix to be of full rank
  extern (C) void dgels_(f_char *trans, f_int *m, f_int *n, f_int *nrhs, f_double *A, f_int *lda,
                         f_double *B, f_int *ldb, f_double *work, f_int *lwork, f_int *info);

  // dgelsy allows covariate matrix to be of less than full rank
  extern (C) void dgelsy_(f_int *m, f_int *n, f_int *nrhs, f_double *A, f_int *lda,
                          f_double *B, f_int *ldb, f_int *jpvt, f_double *rcond,
                          f_int *rank, f_double *work, f_int *lwork, f_int *info);

  // dgemm is BLAS function for matrix multiplication
  extern (C) void dgemm_(f_char *transa, f_char *transb, f_int *m, f_int *n, f_int *k,
                         f_double *alpha, f_double *A, f_int *lda, f_double *B, f_int *ldb,
                         f_double *beta, f_double *C, f_int *ldc);
}

// The D interface is a D-ified call which calls the C interface dgels_
void gels(f_char trans,    // whether to consider A transpose (='N' for standard)
          f_int m,         // number of rows in A
          f_int n,         // number of columns in A
          f_int nrhs,      // number of right-hand sides (no. columns in B)
          f_double *A,     // [m x n] covariate matrix
          f_int lda,       // leading dimension of A [== m]
          f_double *B,     // [m x nrhs] outcome matrix
          f_int ldb,       // leading dimension of B [== m]
          f_double *work,  // [lwork] vector of workspace
          f_int lwork,     // dimension of work [should be >= mn + max(mn, nrhs) where mn=min(m,n)]
          f_int *info)     // on output, =0 indicates success; =-i indicates ith argument had illegal value; =+i if not full rank
{
  // see R-2.15.0/src/module/lapack/dlapack1.f

  dgels_(&trans, &m, &n, &nrhs, A, &lda, B, &ldb, work, &lwork, info);

  if(*info<0) throw new Exception("dgels_: illegal value in argument " ~ to!string(*info));
}

// The D interface is a D-ified call which calls the C interface dgelsy_
void gelsy(f_int m,         // number of rows in A
           f_int n,         // number of columns in A
           f_int nrhs,      // number of right-hand sides (no. columns in B)
           f_double *A,     // [m x n] covariate matrix
           f_int lda,       // leading dimension of A [== m]
           f_double *B,     // [m x nrhs] outcome matrix
           f_int ldb,       // leading dimension of B [== m]
           f_int *jpvt,     // n-vector to keep track of reordering of columns of A
           f_double rcond,  // used to determine the effective rank of A (condition number < 1/rcond)
           f_int *rank,     // on output, the rank of A
           f_double *work,  // [lwork] vector of workspace
           f_int lwork,     // dimension of work [should be >= max(mn+3*n+1, 2*mn+nrhs), where mn=min(m,n)]
           f_int *info)     // on output, =0 indicates success; =-i indicates ith argument had illegal value
{
  // see R-2.15.0/src/module/lapack/dlapack1.f

  dgelsy_(&m, &n, &nrhs, A, &lda, B, &ldb, jpvt, &rcond, rank, work, &lwork, info);

  if(*info!=0) throw new Exception("dgelsy_: illegal value in argument " ~ to!string(*info));
}


// The D interface is a D-ified call which calls the C interface dgemm_
//
// calculates alpha * (A . B) + beta * C
void gemm(f_char transa,    // N: don't transpose A; T/C: tranpose A
          f_char transb,    // N: don't transpose A; T/C: tranpose A
          f_int m,          // number of rows of A and C
          f_int n,          // number of columns of B and C
          f_int k,          // number of columns of A and rows of B
          f_double alpha,   // scalar
          f_double *A,      // matrix A
          f_int lda,        // leading dimension of A (==m)
          f_double *B,      // matrix B
          f_int ldb,        // leading dimension of B (==k)
          f_double beta,    // scalar
          f_double *C,      // matrix C; on output, contains the result
          f_int ldc)        // leading dimension of C
{
  // see http://www.netlib.org/blas/dgemm.f

  dgemm_(&transa, &transb, &m, &n, &k, &alpha, A, &lda, B, &ldb, &beta, C, &ldc);
}


// fit linear regression model and return residual sum of squares
// **ADD** I should follow this with another function that will pull out the estimates
//         and then a third function that will calculate their variance matrix
//         (both making use of the new state of
double[] calc_linreg_rss(double x[], size_t nrow, size_t ncolx, double y[], size_t ncoly,
                         double tol=1e-8)
{
  int lda=cast(int)nrow, ldb=cast(int)nrow, info, rank;

  int lwork = cast(int)max(min(nrow,ncolx) + max(min(nrow,ncolx), ncoly),
                           max(min(nrow,ncolx) + 3*ncolx + 1, 2*min(nrow,ncolx)*ncoly));
  auto work = new double[lwork];

  // to fill with RSS for output
  auto rss = new double[ncoly];
  foreach(i; 0..ncoly) rss[i]=0.0; // fill with 0's

  auto jpvt = new int[ncolx];
  foreach(i; 0..ncolx) jpvt[i] = 0;  // keeps track of pivoted columns

  // save x and y in case x is not of full rank
  auto xcopy = x.dup;
  auto ycopy = y.dup;

  gelsy(cast(int)nrow, cast(int)ncolx, cast(int)ncoly, x.ptr, lda, y.ptr, ldb, jpvt.ptr, tol, &rank, work.ptr, lwork, &info);

  if(rank < ncolx) { // x has < full rank
    // calculate residuals
    gemm('N', 'N', cast(int)nrow, cast(int)ncoly, cast(int)ncolx, 1.0, xcopy.ptr, cast(int)nrow, y.ptr, cast(int)nrow, -1.0, ycopy.ptr, cast(int)nrow);

    // calculate RSS
    auto row_index = 0;
    foreach(i; 0..ncoly) {
      foreach(j; 0..nrow)
        rss[i] += ycopy[row_index+j]^^2;
      row_index += nrow;
    }

    return rss;
  }

  // calculate RSS
  auto row_index = 0;
  foreach(i; 0..ncoly) {
    foreach(j; rank..nrow)
      rss[i] += y[row_index+j]^^2;
    row_index += nrow;
  }

  return rss;
}


double[] calc_linreg_rss_fullrank(double x[], size_t nrow, size_t ncolx, double y[], size_t ncoly,
                                  double tol=1e-8)
{
  int lda=cast(int)nrow, ldb=cast(int)nrow, info, rank;

  int lwork = cast(int)max(min(nrow,ncolx) + max(min(nrow,ncolx), ncoly),
                           max(min(nrow,ncolx) + 3*ncolx + 1, 2*min(nrow,ncolx)*ncoly));
  auto work = new double[lwork];

  // save x and y in case x is not of full rank
  auto xcopy = x.dup;
  auto ycopy = y.dup;

  // to fill with RSS for output
  auto rss = new double[ncoly];
  foreach(i; 0..ncoly) rss[i]=0.0; // fill with 0's

  info = 0;
  gels('N', cast(int)nrow, cast(int)ncolx, cast(int)ncoly, x.ptr, lda, y.ptr, ldb, work.ptr, lwork, &info);

  if(!info) { // check whether x seems singular
    foreach(i; 0..ncolx) {
      if(abs(x[i+i*nrow]) < tol) {
        info = 1;
        break;
      }
    }
  }

  if(info) {
    // dgels didn't work; restore x and y and switch to dgelsy
    x = xcopy.dup;
    y = ycopy.dup;

    return calc_linreg_rss(x, nrow, ncolx, y, ncoly, tol);
  }

  // else: worked; calculate RSS and return
  auto row_index = 0;
  foreach(i; 0..ncoly) {
    foreach(j; ncolx..nrow)
      rss[i] += y[row_index+j]^^2;
    row_index += nrow;
  }
  return rss;
}


/**
 * unit tests
 **/

unittest {
  writeln("Unit test " ~ __FILE__);
  writeln(" --X matrix with full rank");

  double[] x = [ 8, 5, 4, 3, 3,
                 9, 2, 2, 2, 9,
                 5, 1, 8, 1, 4];

  double[] y = [42, 12, 32, 10, 33];

  double rss_R = 0.42328733709665872231;

  int nrow = cast(int)y.length;
  int ncolx = cast(int)x.length / nrow;
  int ncoly = 1;

  // save copies of x and y
  auto xcopy = x.dup;
  auto ycopy = y.dup;

  writeln("   --dgels");
  auto rss = calc_linreg_rss_fullrank(x, nrow, ncolx, y, ncoly);
  assert(abs(rss[0] - rss_R) < 1e-12);

  // restore x and y
  x = xcopy.dup;
  y = ycopy.dup;

  writeln("   --dgelsy");
  rss = calc_linreg_rss(x, nrow, ncolx, y, ncoly);
  assert(abs(rss[0] - rss_R) < 1e-12);
}

unittest {
  writeln(" --X matrix with less than full rank");

  // 3rd col is 2*(1st col) - (4th col)
  // 5th col is noise
  double[] x = [ 8, 5, 4, 3, 3, 1, 5,
                 9, 2, 2, 2, 9, 1, 2,
                 11,9, 0, 5, 2, 1, 7,
                 5, 1, 8, 1, 4, 1, 3,
                 6, 5, 3, 2, 1, 1, 0];

  double[] y = [42, 12, 32, 10, 33, 8, 9];

  double rss_R = 4.4447690235964136818;

  int nrow = cast(int)y.length;
  int ncolx = cast(int)x.length / nrow;
  int ncoly = 1;

  auto xcopy = x.dup;
  auto ycopy = y.dup;

  writeln("   --dgelsy");
  auto rss = calc_linreg_rss(x, nrow, ncolx, y, ncoly);
  assert(abs(rss[0] - rss_R) < 1e-12);

  writeln("   --dgels");
  x = xcopy.dup;
  y = ycopy.dup;
  rss = calc_linreg_rss_fullrank(x, nrow, ncolx, y, ncoly);
  assert(abs(rss[0] - rss_R) <1e-12);
}

unittest {
  writeln(" --Example from nag.com");
  // http://www.nag.com/lapack-ex/node48.html

  double[] x = [-0.09, -1.56, -1.48, -1.09,  0.08, -1.59,
                 0.14,  0.20, -0.43,  0.84,  0.55, -0.72,
                -0.46,  0.29,  0.89,  0.77, -1.13,  1.06,
                 0.68,  1.09, -0.71,  2.11,  0.14,  1.24,
                 1.29,  0.51, -0.96, -1.27,  1.74,  0.34];
  double[] y = [7.4, 4.2, -8.3, 1.8, 8.6, 2.1];
  double[] coef = [0.6344, 0.9699, -1.4402, 3.3678, 3.3992];
  double rss_R = 0.000012077113770668116438;

  int nrow = cast(int)y.length;
  int ncolx = cast(int)x.length / nrow;
  int ncoly = 1;

  // save copies of x and y
  auto xcopy = x.dup;
  auto ycopy = y.dup;

  // run with DGELS method that assumes X is full rank
  writeln("   --dgels");
  auto rss = calc_linreg_rss_fullrank(x, nrow, ncolx, y, ncoly);
  assert(abs(rss[0] - rss_R) < 1e-12);

  // restore x and y
  x = xcopy.dup;
  y = ycopy.dup;

  writeln("   --dgelsy");
  rss = calc_linreg_rss(x, nrow, ncolx, y, ncoly);
  assert(abs(rss[0] - rss_R) < 1e-12);
}


unittest {
  writeln(" --Multiple y columns");

  auto x = [ 0.784, -0.122, 0.363,  0.270, 1.012,
             1.003,  0.346, 0.638,  1.012, 1.714,
             0.956, -0.209, 1.731, -0.570, 0.386];

  auto y = [-2.791, -0.822, -1.570, -2.723, -1.436,
            -2.711, -0.302, -1.978,  1.371, -2.170,
            -2.028, -1.168, -3.345, -1.160, -2.514,
            -1.401, -1.525,  1.773,  1.011,  0.575,
            -0.702, -3.354,  1.655, -0.876, -2.114,
             1.203, -0.547,  1.876, -2.383, -1.522,
            -1.338, -0.701,  0.889, -1.110,  0.792,
             2.843, -1.296,  2.321, -1.622,  2.444,
             3.019,  0.445,  1.930,  1.622,  2.396,
             1.271,  1.035,  0.245, -1.516,  1.538];

  auto rss_R = [3.967646251383592836959, 2.097225399196657846801, 0.024392141058290763705,
                7.741672518864973540076, 8.155596184097051448703, 0.673137917824839115966,
                4.062648885524948738635, 0.318074708703368180807, 1.163078957925449685717,
                4.523679446072986998217];

  int ncoly = 10;
  int nrow = cast(int)y.length/ncoly;
  int ncolx = cast(int)x.length / nrow;

  auto xcopy = x.dup;
  auto ycopy = y.dup;

  // run with DGELS method that assumes X is full rank
  writeln("   --dgels");
  auto rss = calc_linreg_rss_fullrank(x, nrow, ncolx, y, ncoly);
  assert(rss.length == ncoly);
  foreach(i; 0..ncoly)
    assert(abs(rss[i] - rss_R[i]) < 1e-12);

  // restore x and y
  x = xcopy.dup;
  y = ycopy.dup;

  writeln("   --dgelsy");
  rss = calc_linreg_rss(x, nrow, ncolx, y, ncoly);
  assert(rss.length == ncoly);
  foreach(i; 0..ncoly)
    assert(abs(rss[i] - rss_R[i]) < 1e-12);
}


unittest {
  writeln(" --Multiple y columns; X less than full rank");

  auto x = [ 0.784, -0.122,  0.363,  0.270, 1.012,
             1.003,  0.346,  0.638,  1.012, 1.714,
             0.956, -0.209,  1.731, -0.570, 0.386,
            -1.865,  0.973, -4.555,  2.722, 0.556,
             2.743,  0.015,  2.732,  0.712, 3.112];

  auto y = [-2.791, -0.822, -1.570, -2.723, -1.436,
            -2.711, -0.302, -1.978,  1.371, -2.170,
            -2.028, -1.168, -3.345, -1.160, -2.514,
            -1.401, -1.525,  1.773,  1.011,  0.575,
            -0.702, -3.354,  1.655, -0.876, -2.114,
             1.203, -0.547,  1.876, -2.383, -1.522,
            -1.338, -0.701,  0.889, -1.110,  0.792,
             2.843, -1.296,  2.321, -1.622,  2.444,
             3.019,  0.445,  1.930,  1.622,  2.396,
             1.271,  1.035,  0.245, -1.516,  1.538];

  auto rss_R = [3.967646251383592836959, 2.097225399196657846801, 0.024392141058290763705,
                7.741672518864973540076, 8.155596184097051448703, 0.673137917824839115966,
                4.062648885524948738635, 0.318074708703368180807, 1.163078957925449685717,
                4.523679446072986998217];

  int ncoly = 10;
  int nrow = cast(int)y.length/ncoly;
  int ncolx = cast(int)x.length / nrow;

  auto xcopy = x.dup;
  auto ycopy = y.dup;

  // run with DGELS method that assumes X is full rank
  writeln("   --dgels");
  auto rss = calc_linreg_rss_fullrank(x, nrow, ncolx, y, ncoly);
  assert(rss.length == ncoly);
  foreach(i; 0..ncoly)
    assert(abs(rss[i] - rss_R[i]) < 1e-12);

  // restore x and y
  x = xcopy.dup;
  y = ycopy.dup;

  writeln("   --dgelsy");
  rss = calc_linreg_rss(x, nrow, ncolx, y, ncoly);
  assert(rss.length == ncoly);
  foreach(i; 0..ncoly)
    assert(abs(rss[i] - rss_R[i]) < 1e-12);
}
