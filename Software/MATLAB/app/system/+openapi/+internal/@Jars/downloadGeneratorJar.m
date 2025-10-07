function jarPath = downloadGeneratorJar(version, options)
    % DOWNLOADGENERATORJAR Downloads the org.openapitools:openapi-generator jar file
    % The local path to the download is returned as a string.
    % If the file is not found an empty string is returned.
    % The version to download should be provided as a scalar text value.
    %
    % Example:
    %   jarPath = openapi.internal.Jars.downloadGeneratorJar("6.6.0")

    %  (c) 2024-2025 MathWorks, Inc.

    arguments
        version string {mustBeTextScalar, mustBeNonzeroLengthText}
        options.destinationDir = openapiRoot("lib", "jar");
        options.weboptions (1,1) weboptions = weboptions('Timeout', 10)
        options.verbose (1,1) logical = true
    end

    manifest = openapi.internal.Maven.getMvnManifest("org.openapitools", "openapi-generator-cli", weboptions=options.weboptions, verbose=options.verbose);

    jarURL = string.empty;
    for n = 1:numel(manifest)
        if strcmp(version, manifest(n).version)
            jarURL = manifest(n).jarURL;
            sha256URL = manifest(n).sha256URL;
            sha1URL = manifest(n).sha1URL;
            break;
        end
    end

    if isempty(jarURL)
        jarPath = string.empty;
    else
        uri = matlab.net.URI(jarURL);
        queryFields = split(uri.Query(end).Value, "/");
        jarPath = fullfile(options.destinationDir, queryFields(end));
        if options.verbose
            fprintf("Downloading: %s\n", jarURL)
        end
        if ~isfolder(options.destinationDir)
            [status, msg] = mkdir(options.destinationDir);
            if status ~= 1
                error("Directory creation failed for: %s\nMessage: %s", options.destinationDir, msg);
            else
                fprintf("Created directory: %s\n", options.destinationDir);
            end
        end
        % Download JAR
        websave(jarPath, jarURL, options.weboptions);
        
        % Attempt to verify checksum using SHA-256 first, then SHA-1 as fallback
        verified = false;
        expected = "";
        try
            if strlength(sha256URL) > 0
                expected = strtrim(string(webread(sha256URL, options.weboptions))); %#ok<*WEBRD>
                % Some checksum files contain format like "<hex>  <filename>"
                expected = extractBefore(expected, regexp(expected, "\s", 'once'));
                actual = openapi.internal.utils.computeChecksum(jarPath, "SHA-256");
                verified = strcmpi(expected, actual);
            end
        catch
            % ignore and try SHA-1
        end
        if ~verified
            try
                if strlength(sha1URL) > 0
                    expected = strtrim(string(webread(sha1URL, options.weboptions)));
                    expected = extractBefore(expected, regexp(expected, "\s", 'once'));
                    actual = openapi.internal.utils.computeChecksum(jarPath, "SHA-1");
                    verified = strcmpi(expected, actual);
                end
            catch
                % ignore; will error below if still not verified
            end
        end

        if ~verified
            if options.verbose
                fprintf(2, "Checksum verification failed for %s. Expected: %s\n", jarPath, expected);
            end
            if isfile(jarPath)
                delete(jarPath);
            end
            error("Checksum verification failed for downloaded JAR %s", jarURL);
        else
            if options.verbose
                fprintf("Verified checksum for %s\n", jarPath);
            end
        end
    end
end