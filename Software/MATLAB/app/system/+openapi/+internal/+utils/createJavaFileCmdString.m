function cmdStr = createJavaFileCmdString(classpath, configurationFile, options)
    % CREATEJAVAFILECMDSTRING 
    % A string is returned.

    % (c) MathWorks Inc 2024

    arguments
        classpath string {mustBeTextScalar, mustBeNonzeroLengthText}
        configurationFile string {mustBeTextScalar, mustBeNonzeroLengthText}
        options.additionalArguments string {mustBeTextScalar, mustBeNonzeroLengthText}
    end

    javaCmdStr = openapi.internal.utils.createJavaCmdString;
    cmdStr = javaCmdStr + " -cp " + '"' + classpath + '"';
    cmdStr = cmdStr + " --config " + '"' + configurationFile + '"';

    if isfield(options, "additionalArguments")
        % Sanitize additionalArguments to avoid shell metacharacters
        safe = openapi.internal.utils.sanitizeCliArgs(options.additionalArguments);
        if strlength(safe) > 0
            cmdStr = cmdStr + " " + safe;
        end
    end
end