/system script
job remove [find script="limitDynamic"];
remove [find name="limitDynamic"];
add name="limitDynamic" source={

	:local filterARP "br-local";
	:local targetAddress "192.168.10.0/24";
	:local limitClient "3M";
	:local limitParent "30M";
	:local parentLimit "0-Parent";
	:local packetMark "client.p";
	:local delay "60s";

	:local enabled true;
	:local enableLog true;

	/queue simple
	:if ($enabled) do={
		:if ([find name=($parentLimit)] = "") do={	add name=($parentLimit) packet-mark=$packetMark target=$targetAddress max-limit=($limitParent."/".$limitParent);	}
		:if ([find name=($parentLimit."-all")] = "") do={ add name=($parentLimit."-all") parent=$parentLimit packet-mark=$packetMark target=$targetAddress max-limit=($limitParent."/".$limitParent); }
	}

	:while (true) do={

		:local arp [:toarray [/ip arp print as-value where dynamic && interface=$filterARP ]];
		:local queue [:toarray [/queue simple print as-value]];

		:if ($enableLog) do={ :log warning message= "Removing any dynamic queue entry ..."; }
		
		:if ($enabled) do={ /queue simple remove [find (parent=$parentLimit) && (name!=($parentLimit."-all"))]; }

		:if ($enableLog) do={ :log warning message= "All dynamic queue removed."; :log warning message= "Adding new dynamic queue entry ..."; }

		:foreach a in=$arp do={
			:local ip ($a->"address");
			:local zz ($a->"mac-address");
			:if ($enabled) do={/queue simple add name=($zz) target=$ip max-limit=($limitClient."/".$limitClient) parent=$parentLimit packet-mark=$packetMark place-before=($parentLimit."-all"); }
			
		}

		:if ($enableLog) do={ :log warning message= "Finished adding"; :log warning message= "Running delay"; }
		:delay $delay;
	}
}
:execute "/system script run limitDynamic;";

/system scheduler
remove [find name="limitDynamic"];
add name=limitDynamic interval=10m on-event={ :if ([:len [/system script job find script=limitDynamic]] = 0 ) do={/system script run limitDynamic; } }

/file remove [find name="limit-dynamic-mum.rsc"];