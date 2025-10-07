function hex = computeChecksum(filePath, algorithm)
% COMPUTECHECKSUM Compute hex-encoded checksum of a file using Java MessageDigest
%   hex = computeChecksum(filePath, algorithm)
%   algorithm: 'SHA-256' (preferred), or 'SHA-1'

    arguments
        filePath string {mustBeTextScalar, mustBeNonzeroLengthText}
        algorithm string {mustBeMember(upper(algorithm),["SHA-256","SHA-1"])}
    end

    if ~isfile(filePath)
        error('Checksum:fileNotFound','File not found: %s', filePath);
    end

    fis = java.io.FileInputStream(char(filePath));
    try
        md = java.security.MessageDigest.getInstance(char(algorithm));
        buf = zeros(8192,1,'uint8');
        while true
            n = fis.read(buf,0,numel(buf));
            if n <= 0
                break;
            end
            md.update(buf(1:n));
        end
        digest = uint8(md.digest());
    catch ME
        try, fis.close(); end %#ok<TRYNC>
        rethrow(ME);
    end
    fis.close();

    % Convert to lowercase hex string (string scalar)
    hx = dec2hex(digest,2)';        % 2 x N char, transpose to Nx2 -> 2xN becomes Nx2? Actually dec2hex returns N x 2, transpose to 2 x N
    hx = hx(:)';                    % flatten to 1 x (2N)
    hex = lower(string(hx));        % convert to string scalar
end
