classdef Application < dynamicprops
    % APPLICATION main class for implementing MATLAB based API Servers
    % using the MATLAB Web Service

    % Copyright 2025 The MathWorks, Inc.
    properties
       Debug = false
    end    
    properties (Access=private)
        routes cell
    end

    methods
        function app = Application(config)
            % APPLICATION creates a new Application instance
            arguments
                config.?mws.Application
            end
            for p = string(fieldnames(config))'
                app.(p) = config.(p);
            end
        end
        function app = use(app,path,func)
            % USE add a generic handler for all http methods.
            % 
            % Typically used to add middleware.
            
            if isa(path,'function_handle')
                % If no path specified, add for any path
                app.routes{end+1} = {'.*',path};
            else
                % If a path is given, add for this path, but do still add
                % for all http methods
                app.routes{end+1} = {".*? " + path,func};
            end
        end
        function app = get(app,path,func)
            % GET add a get handler to the router
            app.routes{end+1} = {"GET " + app.processPath(path),func};
        end
        function app = post(app,path,func)
            % POST add a post handler to the router
            app.routes{end+1} = {"POST " + app.processPath(path),func};
        end
        function app = put(app,path,func)
            % PUT add a put handler to the router
            app.routes{end+1} = {"PUT " + app.processPath(path),func};
        end
        function app = patch(app,path,func)
            % PATCH add a patch handler to the router
            app.routes{end+1} = {"PATCH " + app.processPath(path),func};
        end
        function app = del(app,path,func)
            % DEL add a del handler to the router
            app.routes{end+1} = {"DELETE " + app.processPath(path),func};
        end

        function response = handleRequest(app,s)
            % HANDLEREQUEST fully handles the request based on the
            % Application configuration.

            % Initialize per-request state as locals to avoid shared mutable state
            currentIndex = 0;
            req = mws.Request(s);
            req.Application = app;
            res = mws.Response();

            % Nested function to iterate routes using local state
            function nextLocal()
                % Split off query parameters
                p = split(s.Path,"?");
                % Remove trailing slashes
                p = strip(p(1),"right","/");
                % Add request method
                p = upper(s.Method) + " " + p;

                for i = currentIndex+1:length(app.routes)
                    currentIndex = i;
                    route = app.routes{i}{1};
                    match = regexp(p,route,"names");
                    if ~isempty(match)
                        % Add matched params to request
                        req.AddParams(match);
                        % Invoke handler with req/res and a continuation
                        feval(app.routes{i}{2}, req, res, @nextLocal);
                        return
                    end
                end
                % No match
                res.SendStatus(404);
            end

            % If anything fails here, return a 500 error
            try
                nextLocal();
                % Return final response
                response = res.GetStruct();
            catch ME
                % Print the error report to internal logging
                fprintf(2,ME.getReport()+"\n");
                if app.Debug
                    response = mws.Response().Status(500).Json(struct('error',ME)).GetStruct();
                else
                    response = struct( ...
                        ApiVersion=[1 0 0], ...
                        HttpCode=500, ...
                        HttpMessage='Internal Server Error');
                end
            end
        end
    end

    methods (Access=private)
        function path = processPath(~,path)
            % PROCESSPATH replaces route parameters with the correct MATLAB
            % regular expressions such that they can be matched as named
            % tokens.

            % Replace any route parameters which are somewhere in the
            % middle of the path 
            % Express style
            path = regexprep(path,"/:([^/]*)/","/(?<$1>[^/]*)/");
            % OpenAPI style
            path = regexprep(path,"/\{([^/]*)\}/","/(?<$1>[^/]*)/");

            % Route parameters at the very end of the path (i.e. not
            % followed by a slash) are handled slightly differently, we
            % make the slash which precedes it optional. We obviously want
            % /foo/:myparam to be callable as /foo/somevalue (where then
            % Params.myparam = "somevalue")*but also* as /foo (where then
            % Params.myparam = "").
            % Express style
            path = regexprep(path,"/:([^/]*)","[/]?(?<$1>[^/]*)");
            % OpenAPI style
            path = regexprep(path,"/\{([^/]*)\}","[/]?(?<$1>[^/]*)");

            % Finally allow OpenAPI style path parameters anywhere in the
            % Path without any further special treatment of requiring
            % slashes or not, only do treat a slash at the end as the end
            % of the parameter
            path = regexprep(path,"\{([^/]*)\}","(?<$1>[^/]*)");
            % Add $ to not allow anything else after the path (other than
            % query parameters, which will be omitted when matching later).
            path = path + "$";
        end        
    end
end