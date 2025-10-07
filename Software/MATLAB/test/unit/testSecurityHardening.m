classdef testSecurityHardening < matlab.unittest.TestCase
    % testSecurityHardening
    % Unit tests for security hardening changes:
    % - computeChecksum (SHA-256/SHA-1)
    % - sanitizeCliArgs and createJavaFileCmdString integration
    % - mws.Application per-request state isolation
    % - Optional: downloadGeneratorJar with checksum verification (network)

    %                 (c) 2025 MathWorks, Inc.

    methods (TestClassSetup)
        function addPaths(~)
            % Ensure repo paths are on MATLAB path for tests
            here = fileparts(mfilename('fullpath'));
            repo = fullfile(here, '..', '..', '..');
            run(fullfile(repo, 'Software', 'MATLAB', 'startup.m'));
        end
    end

    methods (Test)
        function testComputeChecksumSHA256AndSHA1(testCase)
            txt = "hello world";
            tmp = fullfile(tempdir, "checksum_test.txt");
            fid = fopen(tmp,'w'); cleaner = onCleanup(@() fclose('all')); %#ok<NASGU>
            fwrite(fid, txt, 'char'); fclose(fid);

            sha256 = openapi.internal.utils.computeChecksum(tmp, "SHA-256");
            sha1   = openapi.internal.utils.computeChecksum(tmp, "SHA-1");

            exp256 = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9";
            exp1   = "2aae6c35c94fcfb415dbe95f408b9ce91ee846ed";

            testCase.verifyEqual(sha256, exp256);
            testCase.verifyEqual(sha1, exp1);
        end

        function testSanitizeCliArgsValidAndInvalid(testCase)
            % Allowed args should pass unchanged
            ok = "--global-property models,apis --dry-run -Dfoo=bar_baz-1.2/path";
            out = openapi.internal.utils.sanitizeCliArgs(ok);
            testCase.verifyEqual(out, ok);

            % Disallowed tokens should error
            bads = ["--flag; rm -rf /", "--flag && id", "--flag | cat", ...
                    "--flag `whoami`", "--flag $(whoami)"];
            for b = bads
                testCase.verifyError(@() openapi.internal.utils.sanitizeCliArgs(b), 'CLI:InvalidArgument');
            end

            % Disallowed characters (e.g., backtick) should error via InvalidCharacter too
            testCase.verifyError(@() openapi.internal.utils.sanitizeCliArgs("bad`arg"), 'CLI:InvalidCharacter');
        end

        function testCreateJavaFileCmdStringSanitization(testCase)
            cp = "X:/dummy/classpath.jar";  % value format only, not used
            cfg = "X:/dummy/config.json";
            % Safe args included
            s = openapi.internal.utils.createJavaFileCmdString(cp, cfg, additionalArguments="--dry-run -Dk=v");
            testCase.verifyThat(string(s), matlab.unittest.constraints.ContainsSubstring("--dry-run"));

            % Unsafe args rejected
            testCase.verifyError(@() openapi.internal.utils.createJavaFileCmdString(cp, cfg, ...
                additionalArguments="--help && whoami"), 'CLI:InvalidArgument');
        end

        function testServerPerRequestStateIsolation(testCase)
            % Build a simple app and ensure per-request state is local
            app = mws.Application();
            app.get("/ping", @(req,res,next) res.SendText("pong"));
            app.get("/echo/{v}", @(req,res,next) res.Json(struct("v", req.Params.v)));

            % Request 1
            req1 = struct('Path',"/ping", 'Method',"GET", 'Body', uint8([]), 'Headers', []);
            r1 = app.handleRequest(req1);
            testCase.verifyEqual(r1.HttpCode, 200);
            testCase.verifyThat(native2unicode(r1.Body, 'UTF-8'), matlab.unittest.constraints.ContainsSubstring("pong"));

            % Request 2
            req2 = struct('Path',"/echo/abc", 'Method',"GET", 'Body', uint8([]), 'Headers', []);
            r2 = app.handleRequest(req2);
            testCase.verifyEqual(r2.HttpCode, 200);
            testCase.verifyThat(native2unicode(r2.Body,'UTF-8'), matlab.unittest.constraints.ContainsSubstring('abc'));

            % Defensive check: ensure no per-request fields exist on app
            mc = metaclass(app);
            hasCurrReq = ~isempty(findobj(mc.PropertyList, 'Name','currentReq'));
            hasCurrRes = ~isempty(findobj(mc.PropertyList, 'Name','currentRes'));
            hasCurrIdx = ~isempty(findobj(mc.PropertyList, 'Name','currentIndex'));
            testCase.verifyFalse(hasCurrReq || hasCurrRes || hasCurrIdx, ...
                'Application contains per-request state properties');
        end

        function testDownloadGeneratorJarWithChecksum(testCase)
            % Network-dependent: skip gracefully if not available or endpoints fail
            % Determine version from pom.xml helper; fallback to a known value
            try
                verStr = openapi.internal.utils.getGeneratorJarVersion();
                if strlength(verStr) == 0
                    verStr = "7.13.0";
                end
            catch
                verStr = "7.13.0";
            end

            % Get manifest and expected checksum; skip if web not reachable
            try
                m = openapi.internal.Maven.getMvnManifest("org.openapitools","openapi-generator-cli");
                i = find([m.version]==verStr,1);
                testCase.assumeNotEmpty(i, 'Manifest did not contain requested version');
                exp256 = strtrim(string(webread(m(i).sha256URL)));
                % Handle possible "<hex>  <filename>" format
                sp = regexp(exp256, "\s", 'once');
                if ~isempty(sp)
                    exp256 = extractBefore(exp256, sp);
                end
                testCase.assumeTrue(strlength(exp256) > 0, 'No SHA-256 checksum available');
            catch
                testCase.assumeFail('Network unavailable or Maven endpoint not reachable');
            end

            % Download and verify
            jarPath = openapi.internal.Jars.downloadGeneratorJar(verStr, verbose=true);
            testCase.verifyTrue(isfile(jarPath), 'JAR was not downloaded');
            act256 = openapi.internal.utils.computeChecksum(jarPath, "SHA-256");
            testCase.verifyTrue(strcmpi(exp256, act256), 'SHA-256 mismatch after download');
        end
    end
end
