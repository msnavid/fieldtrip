function ft_test_compare(varargin)

% FT_TEST_COMPARE

% Copyright (C) 2017, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

narginchk(2, inf);
command = varargin{1};
feature = varargin{2};
assert(isequal(command, 'compare'));
varargin = varargin(3:end);

optbeg = find(ismember(varargin, {'matlabversion', 'fieldtripversion', 'user', 'hostname', 'branch', 'arch'}));
if ~isempty(optbeg)
  optarg   = varargin(optbeg:end);
  varargin = varargin(1:optbeg-1);
else
  optarg = {};
end

% varargin contains the file (or files) to test
% optarg contains the command-specific options

% construct the query string that will be passed in the URL
query = '?';
queryparam = {'matlabversion', 'fieldtripversion', 'hostname', 'user', 'branch', 'arch'};
for i=1:numel(queryparam)
  val = ft_getopt(optarg, queryparam{i});
  if ~isempty(val)
    query = [query sprintf('%s=%s&', queryparam{i}, val)];
  end
end

options = weboptions('ContentType','json'); % this returns the results as MATLAB structure

results = cell(size(varargin));
functionname = {};
for i=1:numel(varargin)
  result = webread(['http://dashboard.fieldtriptoolbox.org/api/' query sprintf('&%s=%s', feature, varargin{i})], options);
  
  % the documents in the mongoDB database might not fully consistent, in which case they are returned as cell-array containing different structures
  % merge all stuctures into a single struct-array
  result = mergecellstruct(result);
  
  assert(~isempty(result), 'no results were returned for %s %s', feature, varargin{i});
  functionname = cat(1, functionname(:), {result.functionname}');
  results{i} = result;
end

% find the joint set of all functions
functionname = unique(functionname);

% represent a summary of all results in a struct-array
summary = struct();
for i=1:numel(functionname)
  summary(i).function = functionname{i};
  for j=1:numel(varargin)
    sel = find(strcmp({results{j}.functionname}, functionname{i}));
    summary(i).(fixname(varargin{j})) = getresult(results{j}, sel);
  end % for each functionname
end % for each of the features

% convert the struct-array to a table
table = struct2table(summary);
fprintf('%s\n', table{:});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function str = fixname(str)
str = strtrim(base64encode(str));
str(str=='=') = '_';  % replace the '=' sign with '_'
str = ['X' str 'X'];  % start and end with an 'X'

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function str = getresult(result, index)
if isempty(index)
  str = [];
elseif all(istrue([result(index).result]))
  str = 'passed';
elseif all(~istrue([result(index).result]))
  str = 'failed';
else
  % multiple representations of the same test are not consistent
  str = 'ambiguous';
end

