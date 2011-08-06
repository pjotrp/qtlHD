/**
 * hmm_estmap
 */

module qtl.core.hmm_estmap;

// re-estimate inter-marker recombination fractions
mixin template estmapCode(GT, PKGT)
{
  double[] estmap(Genotype!GT[][] genotypes, double[] rec_frac, double error_prob,
		  int max_iterations, double tol, bool verbose)
  {
    if(genotypes[0].length != rec_frac.length+1)
      throw new Exception("no. markers in genotypes doesn't match rec_frac length");
    if(error_prob < 0.0 || error_prob > 1.0)
      throw new Exception("error_prob out of range");
    foreach(rf; rec_frac) {
      if(rf < 0 || rf > 0.5)
	throw new Exception("rec_frac must be >= 0 and <= 0.5");
    }
    if(max_iterations < 0)
      throw new Exception("max_iterations should be >= 0");
    if(tol < 0)
      throw new Exception("tol >= 0");

    int n_individuals = genotypes.length;
    int n_markers = genotypes[0].length;
    auto all_true_geno = allTrueGenoPK(genotypes[0][0].value);

    auto cur_rec_frac = rec_frac.dup; 
    double[int][PKGT] alpha, beta;
    double[PKGT][PKGT] gamma;
    double sum_gamma;
    foreach(it; 0..max_iterations) {
      foreach(ref rf; cur_rec_frac) {
	rf = 0.0;
      }

      foreach(ind; 0..n_individuals) {

	// forward and backward equations
	alpha = forwardEquations(genotypes[ind], all_true_geno, rec_frac, error_prob);
	beta = backwardEquations(genotypes[ind], all_true_geno, rec_frac, error_prob);


	foreach(j; 0..rec_frac.length) {
	  // calculate gamma = log Pr(v1, v2, O)
	  auto sum_gamma_undef = true;
	  foreach(left_gen; all_true_geno) {
	    foreach(right_gen; all_true_geno) {
	      gamma[left_gen][right_gen] = alpha[left_gen][j] + beta[right_gen][j+1] + 
		emit(genotypes[ind][j+1], right_gen, error_prob) +
		step(left_gen, right_gen, rec_frac[j]);

	      if(sum_gamma_undef) {
		sum_gamma_undef = false;
		sum_gamma = gamma[left_gen][right_gen];
	      }
	      else {
		sum_gamma = addlog(sum_gamma, gamma[left_gen][right_gen]);
	      }
	    }
	  }
	  
	  // update cur_rf
	  foreach(left_gen; all_true_geno) {
	    foreach(right_gen; all_true_geno) {
	      cur_rec_frac[j] += nrec(left_gen, right_gen) * exp(gamma[left_gen][right_gen] - sum_gamma);
	    }
	  }
	} /* loop over marker intervals */
	
      } /* loop over individuals */

      /* rescale */
      foreach(ref rf; cur_rec_frac) {
	rf /= n_individuals;
	if(rf < tol/1000.0) rf = tol/1000.0;
	else if(rf > 0.5-tol/1000.0) rf = 0.5-tol/1000.0;
      }

      if(verbose) {
	auto maxdif=0.0;
	double tempdif;
	foreach(j; 0..rec_frac.length) {
	  tempdif = abs(rec_frac[j] - cur_rec_frac[j]);
	  if(tempdif > maxdif) {
	    maxdif = tempdif;
	  }
	}
	writefln("%4d %.12f", it, tempdif);
      }

      /* check convergence */
      auto converged = true;
      foreach(j; 0..rec_frac.length) {
	if(abs(rec_frac[j] - cur_rec_frac[j]) > tol*(cur_rec_frac[j]+tol*100.0)) {
	  converged = false; 
	  break;
	}
      }

      if(converged) break; 

      rec_frac = cur_rec_frac.dup;
    }
    
    /* calculate log likelihood */
    auto loglik = 0.0;
    double curloglik;
    foreach(ind; 0..n_individuals) {

      alpha = forwardEquations(genotypes[ind], all_true_geno, rec_frac, error_prob);

      auto curloglik_undef = true;
      foreach(gen; all_true_geno) {
	if(curloglik_undef) {
	  curloglik_undef = false;
	  curloglik = alpha[gen][rec_frac.length-1];
	}
	else {
	  curloglik = addlog(curloglik, alpha[gen][rec_frac.length-1]);
	}
      }
      loglik += curloglik;
    }

    if(verbose) {
      writefln("loglik = %.3f", loglik);
    }

    return(cur_rec_frac);
  }
}





