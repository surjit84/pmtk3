function [errors, warnings] = debugDemos(subFolder, exclusions)
% Run PMTK3 demos hiding all figures and demo output - displays a report
% * Diplays an HTML report *
% This function keeps running even if a demo fails.
%% Input
%
% subFolder  - all demos are run by default unless a demo subfolder is
%              specified, e.g. Markov_models
%
% exclusions - demos with tags listed in this cell array are skipped
%              default: {'PMTKslow', 'PMTKinteractive', 'PMTKreallySlow'}
%              You should always include PMTKinteractive
%% Output
% * An HTML table is displayed *
% errors  - a struct whose fields are the demos that failed and whos values
%           are the error messages.
%
% warnings - a struct whose fields are the demos with warnings and whos
%            values are the warning messages
%%
warnState = warning('query', 'all');
ignoredWarnings = {
   'MATLAB:RandStream:ReadingInactiveLegacyGeneratorState'  % caused by setSeed
   'MATLAB:dispatcher:nameConflict'                         % caused by shadowFunction
   'MATLAB:Axes:NegativeDataInLogAxis'                      % erroneous log axis warning
                  };
                            
dbstat = dbstatus();
% ensures function cleans up even after ctrl-c
cleaner = onCleanup(@(x)cleanup(warnState, pwd, dbstat));
shadowFunction({'pause', 'input', 'keyboard', 'suplabel'});
cd(tempdir()); 
dbclear('if', 'error');
dbclear('if', 'warning');
if nargin < 1, subFolder = ''; end
if nargin < 2
    %exclusions = {'PMTKslow', 'PMTKinteractive', 'PMTKreallySlow'};
    exclusions = {'PMTKinteractive', 'PMTKreallySlow'};
end
hideFigures();
[demos, excluded] = processExamples({}, exclusions, 0, false, subFolder);
demos    = sort(demos);
excluded = sort(excluded); 
maxname  = max(cellfun(@length, demos));
ndemos   = numel(demos);
demos    = cellfuncell(@(s)s(1:end-2), demos);
errors   = struct();
warnings = struct();
htmlData = cell(ndemos+numel(excluded), 5);
htmlTableColors = repmat({'lightgreen'}, ndemos, 5);
%%
for dm=1:ndemos
    try
        htmlData{dm, 1} = demos{dm};
        fprintf('%d:%s %s%s',dm, repmat(' ', [1, 5-length(num2str(dm))]),...
            demos{dm}, dots(maxname+5-length(demos{dm})));
        lastwarn('');
        warning on all;
        tic;
        localEval(demos{dm}); % run the demo
        t = toc;
        htmlData{dm, 5} = sprintf('%.1f seconds', t);
        [warnmsg, warnid] = lastwarn();
        if isempty(warnmsg) || ismember(warnid, ignoredWarnings); 
            fprintf('PASS\n');
            htmlData{dm, 2} = 'PASS';
        else % demo issued a warning
            warnings.(demos{dm}) = {warnid, warnmsg};
            fprintf('PASS (with warnings)\n');
            htmlData{dm, 2} = 'WARN';
            htmlData{dm, 3} = warnid;
            htmlData{dm, 4} = warnmsg;
            htmlTableColors(dm, :) = {'yellow'};
        end
    catch ME % demo failed
        errors.(demos{dm}) = ME;
        fprintf(2, 'FAIL\n');
        htmlData{dm, 2} = 'FAIL';
        htmlData{dm, 3} = ME.identifier;
        htmlData{dm, 4} = ME.message;
        htmlTableColors(dm, :) = {'red'};
    end
    close all hidden
end
fprintf('%d out of %d failed\n', numel(fieldnames(errors)), numel(demos));
fprintf('%d out of %d have warnings\n', numel(fieldnames(warnings)), numel(demos));

for i = 1:numel(excluded)
    htmlData(ndemos+i, 1) = excluded(i);
    htmlData(ndemos+i, 2) = {'SKIP'};
    htmlTableColors(ndemos+i, :) = {'lightblue'};
end
perm = sortidx(htmlData(:, 1));
htmlData = htmlData(perm, :);
htmlTableColors = htmlTableColors(perm, :);
htmlTable('data', htmlData, ...
    'colNames', ...
    {'Name', 'Status', 'Error Identifier', 'Error Message', 'Time'},...
    'dataColors', htmlTableColors);
end

function cleanup(warnState, currentDir, dbstat)
% called automatically by onCleanup object
fprintf('\n\ncleaning up ...\n');
showFigures();
removeShadows();
warning(warnState);
dbstop(dbstat);
cd(currentDir);
end

function localEval(str)
% evaluate str in this isolated workspace
evalc(str);
end