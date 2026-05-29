%% run_this.m
% EEG→Command→UDP sender for the ESP32 SoftAP

% 1) uploads data
C4_Signal = readmatrix('c4_motor_downsampled.csv');
C4_Signal = C4_Signal(:);

% 2) Runs the DSP
[mu, beta, rms_mu, rms_beta, cmd] = eeg_full_pipeline(C4_Signal);
fprintf("Classified command: %d\n", cmd);

% 3) Set up UDP port
u = udpport("Timeout",1);
espIP   = "192.168.4.1";    
espPort = 4210;             

% 4) Send the command

% 4.1)Builds ASCII payload as char, then turns it into uint8:
msg = sprintf('%d\n', cmd);       
payload = uint8(msg);             

% 4.2) Sends the code:
write(u, payload, espIP, espPort);
fprintf("Sent [%s] to %s:%d\n", msg, espIP, espPort);

try
    resp = read(u, 16, "char");
    if startsWith(resp, "ACK")
        fprintf("✔ ACK received\n");
    else
        warning("Unexpected reply: %s", resp);
    end
catch
    warning("No ACK received—packet may have been lost");
end


%% === Pipeline function ===
function [mu, beta, rms_mu, rms_beta, command] = eeg_full_pipeline(c4)
   
    c4 = c4(:);

    % === MU FILTER ===
    sos_mu = [
        1 0 -1 1 -1.5233 0.9421;
        1 0 -1 1 -1.8148 0.9639;
        1 0 -1 1 -1.4681 0.8444;
        1 0 -1 1 -1.7432 0.8961;
        1 0 -1 1 -1.6688 0.8349;
        1 0 -1 1 -1.4531 0.7782;
        1 0 -1 1 -1.5942 0.7845;
        1 0 -1 1 -1.4751 0.7480;
        1 0 -1 1 -1.5259 0.7524];
    g_mu = [0.1367;0.1367;0.1311;0.1311;0.1271;0.1271;0.1246;0.1246;0.1238;1];
    mu = sos_filter(sos_mu, g_mu, c4);

    % === BETA FILTER ===
    sos_beta = [
        1 0 -1 1  0.0874 0.8035;
        1 0 -1 1 -1.5683 0.8857;
        1 0 -1 1 -1.3668 0.6841;
        1 0 -1 1 -0.0202 0.5140;
        1 0 -1 1 -1.1385 0.5002;
        1 0 -1 1 -0.1996 0.3282;
        1 0 -1 1 -0.8401 0.3309;
        1 0 -1 1 -0.4768 0.2506];
    g_beta = [0.4605;0.4605;0.4092;0.4092;0.3798;0.3798;0.3663;0.3663;1];
    beta = sos_filter(sos_beta, g_beta, c4);

    % === RMS ===
    rms_mu   = filter_rms(mu);
    rms_beta = filter_rms(beta);

    % === Classification ===
    mu_active   = rms_mu(end)   > 0.5;
    beta_active = rms_beta(end) > 0.5;
    command = classify(mu_active, beta_active);
end

function y = sos_filter(sos, g, x)
    n = size(sos,1);
    y = x;
    for i=1:n
        b = sos(i,1:3)*g(i);
        a = sos(i,4:6);
        y = filter(b, a, y);
    end
end

function rms_out = filter_rms(sig)
    N = length(sig);
    win = 125;
    rms_out = zeros(N,1);
    for i = win:N
        block = sig(i-win+1:i);
        rms_out(i) = sqrt(mean(block.^2));
    end
end

function cmd = classify(mu_act, beta_act)
    cmd = uint8(0);
    if mu_act && ~beta_act
        cmd = uint8(2);    
    elseif mu_act &&  beta_act
        cmd = uint8(10);   
    elseif ~mu_act && beta_act
        cmd = uint8(8);    
    end
end
