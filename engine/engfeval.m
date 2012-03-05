function [jobid, puttime] = engfeval(varargin)

% ENGFEVAL evaluates the specified MATLAB function on the input arguments
% using locally or remotely running MATLAB engines.
%
% Use as
%   jobid  = engfeval(fname, arg1, arg2, ...)
%   argout = engget(jobid, ...)
%
% See also ENGGET, ENGCELLFUN, ENGPOOL

% -----------------------------------------------------------------------
% Copyright (C) 2012, Robert Oostenveld
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/
% -----------------------------------------------------------------------

% keep track of the time
stopwatch = tic;

% convert the input arguments into something that strmatch can work with
strargin = varargin;
strargin(~cellfun(@ischar, strargin)) = {''};

% locate the begin of the optional key-value arguments
optbeg = false(size(strargin));
optbeg = optbeg | strcmp('diary',   strargin);
optbeg = optbeg | strcmp('batch',   strargin);
optbeg = find(optbeg, 1, 'first');
optarg = varargin(optbeg:end);

% get the optional input arguments
diary = ft_getopt(optarg, 'diary', []);
batch = ft_getopt(optarg, 'batch', 1);

% skip the optional key-value arguments
if ~isempty(optbeg)
  varargin = varargin(1:(optbeg-1));
end

% start with empty return values
jobid   = [];
puttime = [];

% determine whether the function has been compiled
compile = isstruct(varargin{1});

if isa(varargin{1}, 'function_handle')
  % convert the function handle back into a string (e.g. @plus should be 'plus')
  varargin{1} = func2str(varargin{1});
elseif isa(varargin{1}, 'struct')
  % the function has been compited by qsubcompile
  compiledfun = varargin{1}.executable;
  % continue with the original function name
  varargin{1} = varargin{1}.fname;
end

pool = engpool('info');
if isempty(pool)
  error('engine pool has not been started yet, please see "help engpool"');
end

busy = ~cellfun(@isempty, pool);
if all(busy)
  error('all engines are busy');
end

% find the first free engine
enghandle = find(~busy, 1, 'first');

% create a unique identifier for the job (string)
jobid = generatejobid(batch);

% get the current working directory to store the temp files in
curPwd = getcustompwd();

% each job should have a different random number sequence
randomseed = rand(1)*double(intmax);

% pass some options that influence the remote execution
% options = {'pwd', curPwd, 'path', getcustompath, 'global', getglobal, 'diary', diary, 'memreq', memreq, 'timreq', timreq, 'randomseed', randomseed};
options = {'pwd', curPwd, 'path', getcustompath, 'global', getglobal, 'diary', diary, 'randomseed', randomseed, 'engine', enghandle};

% create the matlab script commands (one entry per line)
matlabscript = [...
  'restoredefaultpath;',...
  sprintf('cd(''%s'');', curPwd),...
  sprintf('addpath(''%s'');', fileparts(mfilename('fullpath'))),...
  sprintf('[argout, optout] = engexec(argin, optin);'),...
  ];

% copy the cell-arrays with the input arguments and the options
engine('put', enghandle, 'argin', varargin);
engine('put', enghandle, 'optin', options);

puttime = toc(stopwatch);
engpool('block', enghandle, jobid);
engine('eval', enghandle, matlabscript);
