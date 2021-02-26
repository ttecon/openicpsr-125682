function test_against_stata
%
% Comparisons with Stata MLE, using data generated by output_for_test_against_stata.do
%

    %prelims
    addpath(genpath(fullfile(fileparts(fileparts(pwd)), 'external'))) 
    addpath(genpath(fullfile(fileparts(fileparts(pwd)), 'depend'))) 
    addpath(genpath(fullfile(fileparts(fileparts(pwd)), 'm'))) 
    estopts_base = MleEstimationOptions('quiet', 1);

    %extract data
    data = MleData('File', '../external/data/test_data.csv', 'format', '%f%f%f%f%f%f%f%f', ...
                  'Delimiter', ',', 'ReadVarNames', true);
    data.var = data.var(1:10^4,:);	
    data.var.Properties.VarNames{1} = 'lhs_var';
    data.var.Properties.VarNames{2} = 'rhs_var1';
    data.var.Properties.VarNames{3} = 'rhs_var2';
    data.var.Properties.VarNames{4} = 'rhs_var3';
    data.var.Properties.VarNames{5} = 'group';
    data.var.Properties.VarNames{7} = 'lhs_logit';
    data.var.Properties.VarNames{8} = 'lhsclust_logit';
    
    %run linear model
    regmodel = LinearRegressionModel('lhs_var', {'rhs_var1','rhs_var2','rhs_var3'});
    est_linear = regmodel.Estimate(data, estopts_base);
    estopts_linear_cons = add_constraint(estopts_base,est_linear.model);
    est_linear_cons = regmodel.Estimate(data, estopts_linear_cons);
    [~, linear_dmvcov] = est_linear.DeltaMethod([],@delta_method_test);
    wald_test_linear = est_linear.WaldTest([],@wald_test,[0;0],10^-8);
    lr_test_linear = est_linear_cons.LRTest(est_linear);
    linear_loglik = GetSumLogLik(regmodel, est_linear.param, data, estopts_base);
    linear_cons_loglik = GetSumLogLik(regmodel, est_linear_cons.param, data, estopts_linear_cons);
    
    %run logit model
    logitmodel = BinaryLogitModel('lhs_logit', {'rhs_var1','rhs_var2','rhs_var3'},...
                                       'mixed_logit', false);
    est_logit = logitmodel.Estimate(data, estopts_base);
    estopts_logit_cons = add_constraint(estopts_base, est_logit.model);
    est_logit_cons = logitmodel.Estimate(data, estopts_logit_cons);
    [~, logit_dmvcov] = est_logit.DeltaMethod([], @delta_method_test);
    wald_test_logit = est_logit.WaldTest([], @wald_test, [0;0], 10^-8);
    lr_test_logit = est_logit_cons.LRTest(est_logit);
    logit_loglik = GetSumLogLik(logitmodel, est_logit.param, data, estopts_base);
    logit_cons_loglik = GetSumLogLik(logitmodel, est_logit_cons.param, data, estopts_logit_cons);

    %run logit model with clustered standard errors
    logitmodel_clust = BinaryLogitModel('lhsclust_logit', {'rhs_var1','rhs_var2','rhs_var3'},...
                                             'mixed_logit', false);
    est_logit_clust = logitmodel_clust.Estimate(data, estopts_base);
    estopts_logit_cons_clust = add_constraint(estopts_base, est_logit_clust.model);
    est_logit_cons_clust = logitmodel_clust.Estimate(data, estopts_logit_cons_clust);
    
    %run xtlogit model with random effects
    xtlogit_data = data;
    xtlogit_data.groupvar = data.var.group;   
    xtlogitmodel = BinaryLogitModel('lhs_logit', {'rhs_var1','rhs_var2','rhs_var3'},...
                                    'mixed_logit', true);
    
    %random effects test must have estimates for eta_sd manually bound
    %(see https://confluence.chicagobooth.edu/display/MLE/Changing+quadacc+and+intpoints+in+MLE+for+constrained+binary+logistic+model)
    estopts_bound = estopts_base;
    estopts_bound.constr.paramlist = xtlogitmodel.paramlist;    
    estopts_bound.constr = estopts_bound.constr.SetLowerBound('eta_sd', 0.01);
    estopts_bound.constr = estopts_bound.constr.SetUpperBound('eta_sd', 1);
    
    est_xtlogit = xtlogitmodel.Estimate(xtlogit_data, estopts_bound);
    estopts_xtlogit_cons = add_constraint(estopts_bound, xtlogitmodel);
    est_xtlogit_cons = xtlogitmodel.Estimate(xtlogit_data, estopts_xtlogit_cons);    
    [~, xtlogit_dmvcov] = est_xtlogit.DeltaMethod([], @delta_method_test);
    wald_test_xtlogit = est_xtlogit.WaldTest([], @wald_test, [0;0], 10^-8);
    lr_test_xtlogit = est_xtlogit_cons.LRTest(est_xtlogit);
    xtlogit_loglik = GetSumLogLik(xtlogitmodel, est_xtlogit.param, xtlogit_data, estopts_bound);
    xtlogit_cons_loglik = GetSumLogLik(xtlogitmodel, est_xtlogit_cons.param, xtlogit_data, estopts_xtlogit_cons);  
    
    %check equality of params
    assertElementsAlmostEqual(stata_order_param(est_linear.param, est_linear.model.indices)',...
                              load('parammat_stataout_linear.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_param(est_linear_cons.param, est_linear_cons.model.indices)',...
                              load('parammat_stataout_linear_cons.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_param(est_logit.param, est_logit.model.indices)',...
                              load('parammat_stataout_logit.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_param(est_logit_cons.param, est_logit_cons.model.indices)',...
                              load('parammat_stataout_logit_cons.txt'), 'absolute', 10^-4)
    %tolerance relaxed (see comments in MLE 47: 
    %                   https://jira.chicagobooth.edu/browse/MLE-47?focusedCommentId=36102)
    assertElementsAlmostEqual(stata_order_param(est_xtlogit.param, est_xtlogit.model.indices)',...
                              load('parammat_stataout_xtlogit.txt'), 'absolute', 10^-3)
    assertElementsAlmostEqual(stata_order_param(est_xtlogit_cons.param, est_xtlogit_cons.model.indices)',...
                              load('parammat_stataout_xtlogit_cons.txt'), 'absolute', 10^-4)                              

    %check equality of vcov
    assertElementsAlmostEqual(stata_order_vcov(est_linear.vcov, est_linear.model.indices)',...
                              load('vcovmat_stataout_linear.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_vcov(est_linear_cons.vcov, est_linear_cons.model.indices)',...
                              load('vcovmat_stataout_linear_cons.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_vcov(est_logit.vcov, est_logit.model.indices)',...
                              load('vcovmat_stataout_logit.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_vcov(est_logit_cons.vcov, est_logit_cons.model.indices)',...
                              load('vcovmat_stataout_logit_cons.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_vcov(est_xtlogit.vcov, est_xtlogit.model.indices)',...
                              load('vcovmat_stataout_xtlogit.txt'), 'absolute', 10^-4)
                                         
    %check equality of vcov_opg and vcov_sandwich and ClusterVCov in logit
    assertElementsAlmostEqual(stata_order_vcov(est_logit.vcov_opg, est_logit.model.indices)',...
                              load('opg_stataout_logit.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_vcov(est_logit_cons.vcov_opg, est_logit_cons.model.indices)',...
                              load('opg_stataout_logit_cons.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_vcov(est_logit.vcov_sandwich, est_logit.model.indices)',...
                              load('robust_stataout_logit.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_vcov(est_logit_cons.vcov_sandwich, est_logit_cons.model.indices)',...
                              load('robust_stataout_logit_cons.txt'), 'absolute', 10^-4)                             
    assertElementsAlmostEqual(stata_order_vcov(est_logit_clust.ClusterVCov(data.var.group), est_logit_clust.model.indices)',...
                              load('cluster_stataout_logit.txt'), 'absolute', 10^-4)
    assertElementsAlmostEqual(stata_order_vcov(est_logit_cons_clust.ClusterVCov(data.var.group), est_logit_cons_clust.model.indices)',...
                              load('cluster_stataout_logit_cons.txt'), 'absolute', 10^-4)     

    %check equality of delta_method vcov
    assertElementsAlmostEqual(linear_dmvcov, load('deltamethod_stataout_linear.txt'),...
                              'absolute', 10^-4)
    assertElementsAlmostEqual(logit_dmvcov, load('deltamethod_stataout_logit.txt'),...
                              'absolute', 10^-4)
    assertElementsAlmostEqual(xtlogit_dmvcov, load('deltamethod_stataout_xtlogit.txt'),...
                              'absolute', 10^-4)    
    
    %check equality of wald_test
    assertElementsAlmostEqual(stata_order_wald(wald_test_linear), load('waldtest_stataout_linear.txt'),...
                              'absolute', 10^-3)
    assertElementsAlmostEqual(stata_order_wald(wald_test_logit), load('waldtest_stataout_logit.txt'),...
                              'absolute', 10^-3)
    %tolerance relaxed (see comments in MLE 47: 
    %                   https://jira.chicagobooth.edu/browse/MLE-47?focusedCommentId=36102)
    assertElementsAlmostEqual(stata_order_wald(wald_test_xtlogit), load('waldtest_stataout_xtlogit.txt'),...
                              'absolute', 10^-2)	                              
                            
    %check equality of lr_test
    assertElementsAlmostEqual(stata_order_lr(lr_test_linear), load('lrtest_stataout_linear.txt'),...
                              'absolute', 10^-3)
    assertElementsAlmostEqual(stata_order_lr(lr_test_logit), load('lrtest_stataout_logit.txt'),...
                              'absolute', 10^-3)
    assertElementsAlmostEqual(stata_order_lr(lr_test_xtlogit), load('lrtest_stataout_xtlogit.txt'),...
                              'absolute', 10^-3)

    %check equality of log-likelihood
    assertElementsAlmostEqual(linear_loglik, load('loglik_stataout_linear.txt'),...
                              'absolute', 10^-2)
    assertElementsAlmostEqual(linear_cons_loglik, load('loglik_stataout_linear_cons.txt'),...
                              'absolute', 10^-2)
    assertElementsAlmostEqual(logit_loglik, load('loglik_stataout_logit.txt'),...
                              'absolute', 10^-2)
    assertElementsAlmostEqual(logit_cons_loglik, load('loglik_stataout_logit_cons.txt'),...
                              'absolute', 10^-2)
    assertElementsAlmostEqual(xtlogit_loglik, load('loglik_stataout_xtlogit.txt'),...
                              'absolute', 10^-2)
    assertElementsAlmostEqual(xtlogit_cons_loglik, load('loglik_stataout_xtlogit_cons.txt'),...
                              'absolute', 10^-2)                              
                              
    cleanup()
end

%adds fixed constraint rhs_var1 + rhs_var2 = 1, to match stata
function [estopts_cons] = add_constraint(oldops, model)
    Aeq = zeros(size(model.paramlist));
    Aeq(model.indices.rhs_var1_coeff) = 1;
    Aeq(model.indices.rhs_var2_coeff) = 1;
    beq = 1;
    
    estopts_cons = oldops;
    estopts_cons.constr.Aeq = Aeq;
    estopts_cons.constr.beq = beq;
end

%delta method function to match Stata
function [ delta_method_test ] = delta_method_test( param )
    delta_method_test(1) = param(2) - param(3); 
    delta_method_test(2) = 5 * param(3) + param(3)^2; 
    delta_method_test(3) = param(2) * param(3) * param(4);
end

%wald test function to match Stata
function [ wald_test ] = wald_test( param )
    wald_test = zeros(2,1);
    wald_test(1) = param(2) - param(3); 
    wald_test(2) = 1/param(3) - param(4)^2;
end

%reorder param vector to match Stata
function [stata_order_param] = stata_order_param(param, indices)
    stata_order_param = [param(indices.rhs_var1_coeff); param(indices.rhs_var2_coeff);...
                         param(indices.rhs_var3_coeff); param(indices.constant)];
end

%reorder wald test output to match Stata
function [stata_order_wald] = stata_order_wald(wald_output)
    stata_order_wald = [wald_output.wald_statistic, wald_output.dof, wald_output.pvalue];
end

%reorder lr test output to match Stata
function [stata_order_lr] = stata_order_lr(lr_output)
    stata_order_lr = [lr_output.lr_statistic, lr_output.dof, lr_output.pvalue];
end

%ugly code to reorder vcov matrix to match Stata
function [stata_order_vcov] = stata_order_vcov(vcov, indices)
    stata_order_vcov = vcov(indices.rhs_var1_coeff:indices.rhs_var3_coeff,...
                            indices.rhs_var1_coeff:indices.rhs_var3_coeff);
    stata_order_vcov = [stata_order_vcov; vcov(indices.constant,...
                        indices.rhs_var1_coeff:indices.rhs_var3_coeff)];
    stata_order_vcov = [stata_order_vcov, [vcov(indices.rhs_var1_coeff:indices.rhs_var3_coeff,...
                        indices.constant); vcov(indices.constant, indices.constant)]];
end

function [] = cleanup()
    delete('parammat_stataout_linear.txt', 'parammat_stataout_linear_cons.txt',...
           'parammat_stataout_logit.txt', 'parammat_stataout_logit_cons.txt',...
           'parammat_stataout_xtlogit.txt', 'parammat_stataout_xtlogit_cons.txt',...
           'vcovmat_stataout_linear.txt', 'vcovmat_stataout_linear_cons.txt',...
           'vcovmat_stataout_logit.txt', 'vcovmat_stataout_logit_cons.txt',...
           'vcovmat_stataout_xtlogit.txt', 'vcovmat_stataout_xtlogit_cons.txt',...
           'deltamethod_stataout_linear.txt', 'deltamethod_stataout_logit.txt',...
           'deltamethod_stataout_xtlogit.txt',...
           'waldtest_stataout_linear.txt', 'waldtest_stataout_logit.txt',...
           'waldtest_stataout_xtlogit.txt',...
           'lrtest_stataout_linear.txt', 'lrtest_stataout_logit.txt',...
           'lrtest_stataout_xtlogit.txt',...
           'opg_stataout_logit.txt', 'opg_stataout_logit_cons.txt',...
           'robust_stataout_logit.txt', 'robust_stataout_logit_cons.txt',...
           'cluster_stataout_logit.txt', 'cluster_stataout_logit_cons.txt',...
           'loglik_stataout_linear.txt', 'loglik_stataout_linear_cons.txt',...
           'loglik_stataout_logit.txt', 'loglik_stataout_logit_cons.txt',...
           'loglik_stataout_xtlogit.txt', 'loglik_stataout_xtlogit_cons.txt');
end

