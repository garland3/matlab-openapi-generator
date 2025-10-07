function out = sanitizeCliArgs(in)
% SANITIZECLIARGS Restrict CLI argument string to a safe subset
% Removes/blocks shell metacharacters that could inject commands when
% passed to system(). Allowed characters are conservative.

    arguments
        in string {mustBeTextScalar}
    end

    if strlength(in) == 0
        out = "";
        return;
    end

    % Reject common dangerous tokens outright
    forbidden = ["`","$()","||","&&",";","|",">","<","\n","\r"];
    s = char(in);
    for k = 1:numel(forbidden)
        if contains(s, forbidden{k})
            error('CLI:InvalidArgument','additionalArguments contains forbidden sequence: %s', forbidden{k});
        end
    end

    % Allowlist characters: letters, numbers, space, dash, underscore,
    % dot, slash, equals, comma, colon, plus, quotes
    % Quotes are kept but note they are already wrapped at higher level.
    mask = ismember(s, ['a':'z','A':'Z','0':'9',' ', '-', '_', '.', '/', '=', ',', ':', '+', '"', ''' ]);
    if any(~mask)
        % If disallowed characters exist, block explicitly
        badChars = unique(s(~mask));
        error('CLI:InvalidCharacter','additionalArguments contains invalid characters: %s', string(badChars));
    end

    out = string(s);
end
