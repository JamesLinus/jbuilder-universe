/*******************************************************/
/* CUDF solver: cud.c                                  */
/* main of the cudf solver                             */
/* (c) Claude Michel I3S (UNSA-CNRS) 2009,2010,2011    */
/*******************************************************/


#include <cudf.h>
#include <abstract_solver.h>
#include <constraint_generation.h>
#include <criteria.h>
#include <combiner.h>
#include <cudf_reductions.h>
#include <sys/stat.h>
#include <errno.h>
#include <sstream>
#include <mccscudf.h>

// underlying solver declaration
// allows using solvers withour having to include the whole solver classes
//extern abstract_solver *new_lp_solver(char *lpsolver);
/* extern abstract_solver *new_pblib_solver(char *pbsolver); */
//extern abstract_solver *new_ampl_solver(char *amplsolver);
#ifdef USECPLEX 
extern abstract_solver *new_cplex_solver();
#endif
#ifdef USEGUROBI
extern abstract_solver *new_gurobi_solver();
#endif
#ifdef USELPSOLVE 
extern abstract_solver *new_lpsolve_solver();
#endif
#ifdef USEGLPK
extern abstract_solver *new_glpk_solver(bool use_exact);
#endif

bool criteria_opt_var = false;
// Basic user defined criteria option handling
int get_criteria_options(char *crit_descr, unsigned int &pos, vector< pair<unsigned int, unsigned int> *> *opts) {

  if (crit_descr[pos] == '[') {
    int nb_read = 0;
    unsigned int start = ++pos;

    for (; pos < strlen(crit_descr); pos++)
      switch(crit_descr[pos]) {
      case '[':
	crit_descr[pos] = '\0';
	fprintf(stderr, "ERROR: criteria options: found '[' within criteria options: %s.\n", crit_descr);
	exit(-1);
	break;
      case ']': 
	{
	  unsigned int length = pos - start;
	  if (length == 0) {
	    crit_descr[pos] = '\0';
	    fprintf(stderr, "ERROR: criteria options: found empty criteria option: %s.\n", crit_descr);
	    exit(-1);
	  }
	  opts->push_back(new pair<unsigned int, unsigned int>(start, length));
	  nb_read++;
	  pos++; // ignore ending ']'
	  return nb_read;
	}
	break;
      case ',':
	{
	  unsigned int length = pos - start;
	  if (length == 0) {
	    crit_descr[pos] = '\0';
	    fprintf(stderr, "ERROR: criteria options: found empty criteria option: %s.\n", crit_descr);
	    exit(-1);
	  }
	  opts->push_back(new pair<unsigned int, unsigned int>(start, length));
	  nb_read++;
	  start = ++pos;
	}
	break;
      }

    fprintf(stderr, "ERROR: criteria options: criteria options ended without an ending ']': %s.\n", crit_descr);
    exit(-1);
  } 

  return 0;
}

// Get user defined weight for a criteria
CUDFcoefficient get_criteria_lambda(char *crit_descr, unsigned int &pos, char sign) {
  CUDFcoefficient lambda = 1;
  vector< pair<unsigned int, unsigned int> *> opts;

  int n = get_criteria_options(crit_descr, pos, &opts);

  if (n == 1) {
    unsigned int start = opts[0]->first;
    unsigned int length = opts[0]->second;

    for (unsigned int i = 0; i < length; i++) 
      if ((crit_descr[start+i] < '0') || (crit_descr[start+i] > '9')) {
	crit_descr[start+i+1] = '\0';
	fprintf(stderr, "ERROR: criteria options: a lambda value must be an integer int: %s\n", crit_descr);
	exit(-1);
      }

    if (sscanf(crit_descr+start, CUDFflags, &lambda) != 1) {
      crit_descr[start+length+1] = '\0';
      fprintf(stderr, "ERROR: criteria options: a lambda value is espected here: %s\n", crit_descr);
      exit(-1);
    }
  } else if (n > 1) {
    crit_descr[pos] = '\0';
    fprintf(stderr, "ERROR: criteria options: a lambda value is espected here: %s\n", crit_descr);
    exit(-1);
  }

  if (sign == '+') lambda *= -1;

  return lambda;
}

// Get property name from a user defined criteria
char *get_criteria_property_name(char *crit_descr, unsigned int &pos) {
  vector< pair<unsigned int, unsigned int> *> opts;
  char *property = (char *)NULL;

  int n = get_criteria_options(crit_descr, pos, &opts);

  if (n == 1) {
    unsigned int start = opts[0]->first;
    unsigned int length = opts[0]->second;

    if (crit_descr[start+length-1] == ':') length--;

    if ((property = (char *)malloc((length+1)*sizeof(char))) == (char *)NULL) {
      fprintf(stderr, "ERROR: criteria options: not enough memory to store property name.\n");
      exit(-1);
    }
    
    strncpy(property, crit_descr+start, length);
    property[length] = '\0';
  } else {
    crit_descr[pos] = '\0';
    fprintf(stderr, "ERROR: criteria options: a property name is required here: %s\n", crit_descr);
    exit(-1);
  }

  return property;
}

// Get name and boolean options from user defined criteria
char *get_criteria_property_name_and_bool(char *crit_descr, unsigned int &pos, bool &value) {
  vector< pair<unsigned int, unsigned int> *> opts;
  char *property = (char *)NULL;

  int n = get_criteria_options(crit_descr, pos, &opts);

  if (n == 2) {
    unsigned int start = opts[0]->first;
    unsigned int length = opts[0]->second;

    if (crit_descr[start+length-1] == ':') length--;

    if ((property = (char *)malloc((length+1)*sizeof(char))) == (char *)NULL) {
      fprintf(stderr, "ERROR: criteria options: not enough memory to store property name.\n");
      exit(-1);
    }
    
    strncpy(property, crit_descr+start, length);
    property[length] = '\0';

    start = opts[1]->first;
    length = opts[1]->second;

    if ((length == 4) && 
	(crit_descr[start+0] == 't') &&
	(crit_descr[start+1] == 'r') &&
	(crit_descr[start+2] == 'u') &&
	(crit_descr[start+3] == 'e')) 
      value = true;
    else if ((length == 5) && 
	     (crit_descr[start+0] == 'f') &&
	     (crit_descr[start+1] == 'a') &&
	     (crit_descr[start+2] == 'l') &&
	     (crit_descr[start+3] == 's') &&
	     (crit_descr[start+4] == 'e'))
      value = false;
    else {
      crit_descr[start+length] = '\0';
      fprintf(stderr, "ERROR: criteria options: a boolean is required here (either 'true' or 'false'): %s\n", crit_descr);
      exit(-1);
    }
  } else {
    crit_descr[pos] = '\0';
    fprintf(stderr, "ERROR: criteria options: a property name and a booleen are required here: %s\n", crit_descr);
    exit(-1);
  }

  return property;
}

// Process a user defined criteria
CriteriaList *process_criteria(char *crit_descr, unsigned int &pos, bool first_level, vector<abstract_criteria *> *criteria_with_property) {
  CriteriaList *criteria = new CriteriaList();

  if (crit_descr[pos] == '[') {
    for (pos += 1; pos < strlen(crit_descr) && crit_descr[pos] != ']';) {
      unsigned int sign, crit_name, crit_name_length;

      // check for criteria sense
      switch (crit_descr[pos]) {
      case '+':
      case '-':
	sign = pos++;
	crit_name = pos;
	break;
      default:
	fprintf(stderr, "ERROR: criteria options: a criteria description must begin with a sign which gives its sense (- = min, + = max): %s\n", 
		crit_descr+pos);
	exit(-1);
	break;
      }

      // look for end of criteria name
      for (; pos < strlen(crit_descr); pos++) {
	char c = crit_descr[pos];
	if ((c == ',') || (c == '[') || (c == ']')) break; 
      }
      crit_name_length = pos - crit_name;

      // handle criteria
      if (strncmp(crit_descr+crit_name, "removed", crit_name_length) == 0) {
	criteria->push_back(new removed_criteria(get_criteria_lambda(crit_descr, pos, crit_descr[sign])));
      } else if (strncmp(crit_descr+crit_name, "changed", crit_name_length) == 0) {
	criteria->push_back(new changed_criteria(get_criteria_lambda(crit_descr, pos, crit_descr[sign])));
      } else if (strncmp(crit_descr+crit_name, "new", crit_name_length) == 0) {
	criteria->push_back(new new_criteria(get_criteria_lambda(crit_descr, pos, crit_descr[sign])));
      } else if (strncmp(crit_descr+crit_name, "notuptodate", crit_name_length) == 0) {
	criteria->push_back(new notuptodate_criteria(get_criteria_lambda(crit_descr, pos, crit_descr[sign])));
      } else if (strncmp(crit_descr+crit_name, "count", crit_name_length) == 0) {
	bool onlynew = false;
	char *property_name = get_criteria_property_name_and_bool(crit_descr, pos, onlynew);
	if (property_name != (char *)NULL) {
	  abstract_criteria *crit = new count_criteria(property_name, onlynew, get_criteria_lambda(crit_descr, pos, crit_descr[sign]));
	  criteria_with_property->push_back(crit);
	  criteria->push_back(crit);
	}
      } else if (strncmp(crit_descr+crit_name, "lexagregate", crit_name_length) == 0) {
	criteria->push_back(new lexagregate_combiner(process_criteria(crit_descr, pos, false, criteria_with_property), 
						     get_criteria_lambda(crit_descr, pos, crit_descr[sign])));
      } else {
	crit_descr[pos] = '\0';
	fprintf(stderr, "ERROR: criteria options: this is not a criteria: %s\n", crit_descr+crit_name);
	exit(-1);
      }

      if (crit_descr[pos] == ',') pos++; // skip comma
    }
  } else {
    fprintf(stderr, "ERROR: criteria options: a criteria list must begin with a '[': %s\n", crit_descr+pos);
    exit(-1);
  }

  pos++;
  return criteria;
}

// Handling user criteria definitions
CriteriaList *get_criteria(char *crit_descr, bool first_level, vector<abstract_criteria *> *criteria_with_property) {
  unsigned int pos = 0;
  return process_criteria(crit_descr, pos, first_level, criteria_with_property);
}

Solver_return call_mccs(Solver solver_arg, char *criteria_arg, CUDFproblem* the_problem) {
  // CUDFproblem *problem;
  vector<abstract_criteria *> criteria_with_property;
  CriteriaList *criteria = get_criteria(criteria_arg, false, &criteria_with_property);
  abstract_solver *solver = (abstract_solver *)NULL;
  abstract_combiner *combiner = (abstract_combiner *)NULL;
  stringstream solution;
  Solver_return ret = { 0, "", NULL };

  if (criteria->size() == 0) {
    ret.error = "invalid criteria";
    return ret;
  }
  combiner = new lexagregate_combiner(criteria);

  switch (solver_arg) {
#ifdef USECPLEX
  case CPLEX: solver = new_cplex_solver(); break;
#else
  case CPLEX: ret.error = "This mccs is built without cplex support"; return ret;
#endif
#ifdef USEGUROBI
  case GUROBI: solver = new_gurobi_solver(); break;
#else
  case GUROBI: ret.error = "This mccs is built without gurobi support"; return ret;
#endif
#ifdef USELPSOLVE
  case LPSOLVE: solver = new_lpsolve_solver(); break;
#else
  case LPSOLVE: ret.error = "This mccs is built without lpsolve support"; return ret;
#endif
#ifdef USEGLPK
  case GLPK: solver = new_glpk_solver(false); break;
#else
  case GLPK: ret.error = "This mccs is built without glpk support"; return ret;
#endif
  default: ret.error = "Unrecognised solver specified"; return ret;
  }

  // check criteria properties
  for (vector<abstract_criteria *>::iterator icrit = criteria_with_property.begin(); icrit != criteria_with_property.end(); icrit++)
    (*icrit)->check_property(the_problem);

  // if (combiner->can_reduce()) {
  //   if (verbosity > 0) fprintf(stdout, "Can reduce graph.\n");
  // } else {
  //   use_reduced = false;
  //   if (verbosity > 0) fprintf(stdout, "Can NOT reduce graph.\n");
  // }
  // problem = compute_reduced_CUDF(the_problem);

  // combiner initialization
  combiner->initialize(the_problem, solver);
  
  // generate the constraints, solve the problem and print out the solutions
  if ((the_problem->all_packages->size() > 0) && (generate_constraints(the_problem, *solver, *combiner) == 0) && (solver->solve())) {
    delete combiner;
    for (auto it = criteria->begin(); it != criteria->end(); it++) delete(*it);
    delete criteria;

    solver->init_solutions();

    double obj = solver->objective_value();
    if (verbosity > 2) {
      fprintf(stdout, "================================================================\n");
      printf("Objective value: %f\n", obj);

      for (CUDFVersionedPackageListIterator ipkg = the_problem->all_packages->begin(); ipkg != the_problem->all_packages->end(); ipkg++)
	printf("%s = " CUDFflags"\n", (*ipkg)->versioned_name, solver->get_solution(*ipkg));
      
      fprintf(stdout, "================================================================\n");
    
     }

    ret.success = 1;
    ret.solution = solver;
    return ret;
  } else {
    delete combiner;
    for (auto it = criteria->begin(); it != criteria->end(); it++) delete(*it);
    delete criteria;

    if (verbosity > 0) {
      fprintf(stdout, "================================================================\n");
      fprintf(stdout, "No solution found.\n");
    }
    ret.success = 1;
    return ret;
  }
}