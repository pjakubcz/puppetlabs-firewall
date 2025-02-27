#!/usr/bin/env rspec # rubocop:disable Lint/ScriptPermission : Puppet error?
# frozen_string_literal: true

require 'spec_helper'
require 'puppet/confine/exists'

describe 'iptables provider detection' do # rubocop:disable RSpec/MultipleDescribes
  let(:exists) do
    Puppet::Confine::Exists
  end

  before :each do
    # Reset the default provider
    Puppet::Type.type(:firewall).defaultprovider = nil

    # Stub confine facts
    allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
    allow(Facter.fact(:operatingsystem)).to receive(:value).and_return('Debian')
  end

  it 'is expected to default to iptables provider if /sbin/iptables[-save] exists' do
    # Stub lookup for /sbin/iptables & /sbin/iptables-save
    allow(exists).to receive(:which).with('iptables').and_return '/sbin/iptables'
    allow(exists).to receive(:which).with('iptables-save').and_return '/sbin/iptables-save'

    # Every other command is expected to return false so we don't pick up any
    # other providers
    allow(exists).to receive(:which) { |value| !['iptables', 'iptables-save'].include?(value) }.and_return false

    # Create a resource instance and make sure the provider is iptables
    resource = Puppet::Type.type(:firewall).new(name: '000 test foo')
    expect(resource.provider.class.to_s).to eq('Puppet::Type::Firewall::ProviderIptables')
  end
end

describe 'iptables provider' do
  let(:provider) { Puppet::Type.type(:firewall).provider(:iptables) }
  let(:resource) do
    Puppet::Type.type(:firewall).new(name: '000 test foo',
                                     action: 'accept')
  end

  before :each do
    allow(Puppet::Type::Firewall).to receive(:defaultprovider).and_return provider
    allow(provider).to receive(:command).with(:iptables_save).and_return '/sbin/iptables-save'

    # Stub iptables version
    allow(Facter.fact(:iptables_version)).to receive(:value).and_return('1.4.2')

    allow(Puppet::Util::Execution).to receive(:execute).and_return ''
    allow(Puppet::Util).to receive(:which).with('iptables-save')
                                          .and_return '/sbin/iptables-save'
  end

  it 'is expected to be able to get a list of existing rules' do
    provider.instances.each do |rule|
      expect(rule).to be_instance_of(provider)
      expect(rule.properties[:provider].to_s).to eq(provider.name.to_s)
    end
  end

  it 'is expected to ignore lines with fatal errors' do
    allow(Puppet::Util::Execution).to receive(:execute).with(['/sbin/iptables-save'])
                                                       .and_return('FATAL: Could not load /lib/modules/2.6.18-028stab095.1/modules.dep: No such file or directory')

    expect(provider.instances.length).to be_zero
  end

  describe '#insert_order' do
    let(:iptables_save_output) do
      [
        '-A INPUT -s 8.0.0.2/32 -p tcp -m multiport --ports 100 -m comment --comment "100 test" -j ACCEPT',
        '-A INPUT -s 8.0.0.3/32 -p tcp -m multiport --ports 200 -m comment --comment "200 test" -j ACCEPT',
        '-A INPUT -s 8.0.0.4/32 -p tcp -m multiport --ports 300 -m comment --comment "300 test" -j ACCEPT',
      ]
    end
    let(:resources) do
      iptables_save_output.each_with_index.map { |l, index| provider.rule_to_hash(l, 'filter', index) }
    end
    let(:providers) do
      resources.map { |r| provider.new(r) }
    end

    it 'understands offsets for adding rules to the beginning' do
      resource = Puppet::Type.type(:firewall).new(name: '001 test')
      allow(resource.provider.class).to receive(:instances).and_return(providers)
      expect(resource.provider.insert_order).to eq(1) # 1-indexed
    end
    it 'understands offsets for editing rules at the beginning' do
      resource = Puppet::Type.type(:firewall).new(name: '100 test')
      allow(resource.provider.class).to receive(:instances).and_return(providers)
      expect(resource.provider.insert_order).to eq(1)
    end
    it 'understands offsets for adding rules to the middle' do
      resource = Puppet::Type.type(:firewall).new(name: '101 test')
      allow(resource.provider.class).to receive(:instances).and_return(providers)
      expect(resource.provider.insert_order).to eq(2)
    end
    it 'understands offsets for editing rules at the middle' do
      resource = Puppet::Type.type(:firewall).new(name: '200 test')
      allow(resource.provider.class).to receive(:instances).and_return(providers)
      expect(resource.provider.insert_order).to eq(2)
    end
    it 'understands offsets for adding rules to the end' do
      resource = Puppet::Type.type(:firewall).new(name: '301 test')
      allow(resource.provider.class).to receive(:instances).and_return(providers)
      expect(resource.provider.insert_order).to eq(4)
    end
    it 'understands offsets for editing rules at the end' do
      resource = Puppet::Type.type(:firewall).new(name: '300 test')
      allow(resource.provider.class).to receive(:instances).and_return(providers)
      expect(resource.provider.insert_order).to eq(3)
    end

    context 'with unname rules between' do
      let(:iptables_save_output) do
        [
          '-A INPUT -s 8.0.0.2/32 -p tcp -m multiport --ports 100 -m comment --comment "100 test" -j ACCEPT',
          '-A INPUT -s 8.0.0.2/32 -p tcp -m multiport --ports 150 -m comment --comment "150 test" -j ACCEPT',
          '-A INPUT -s 8.0.0.3/32 -p tcp -m multiport --ports 200 -j ACCEPT',
          '-A INPUT -s 8.0.0.3/32 -p tcp -m multiport --ports 250 -j ACCEPT',
          '-A INPUT -s 8.0.0.4/32 -p tcp -m multiport --ports 300 -m comment --comment "300 test" -j ACCEPT',
          '-A INPUT -s 8.0.0.4/32 -p tcp -m multiport --ports 350 -m comment --comment "350 test" -j ACCEPT',
        ]
      end

      it 'understands offsets for adding rules before unnamed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '001 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(1)
      end
      it 'understands offsets for editing rules before unnamed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '100 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(1)
      end
      it 'understands offsets for adding rules between managed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '120 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(2)
      end
      it 'understands offsets for adding rules between unnamed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '151 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(3)
      end
      it 'understands offsets for adding rules after unnamed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '351 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(7)
      end
    end

    context 'with unname rules before and after' do
      let(:iptables_save_output) do
        [
          '-A INPUT -s 8.0.0.3/32 -p tcp -m multiport --ports 050 -j ACCEPT',
          '-A INPUT -s 8.0.0.3/32 -p tcp -m multiport --ports 090 -j ACCEPT',
          '-A INPUT -s 8.0.0.2/32 -p tcp -m multiport --ports 100 -m comment --comment "100 test" -j ACCEPT',
          '-A INPUT -s 8.0.0.2/32 -p tcp -m multiport --ports 150 -m comment --comment "150 test" -j ACCEPT',
          '-A INPUT -s 8.0.0.3/32 -p tcp -m multiport --ports 200 -j ACCEPT',
          '-A INPUT -s 8.0.0.3/32 -p tcp -m multiport --ports 250 -j ACCEPT',
          '-A INPUT -s 8.0.0.4/32 -p tcp -m multiport --ports 300 -m comment --comment "300 test" -j ACCEPT',
          '-A INPUT -s 8.0.0.4/32 -p tcp -m multiport --ports 350 -m comment --comment "350 test" -j ACCEPT',
          '-A INPUT -s 8.0.0.5/32 -p tcp -m multiport --ports 400 -j ACCEPT',
          '-A INPUT -s 8.0.0.5/32 -p tcp -m multiport --ports 450 -j ACCEPT',
        ]
      end

      it 'understands offsets for adding rules before unnamed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '001 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(1)
      end
      it 'understands offsets for editing rules before unnamed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '100 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(3)
      end
      it 'understands offsets for adding rules between managed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '120 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(4)
      end
      it 'understands offsets for adding rules between unnamed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '151 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(5)
      end
      it 'understands offsets for adding rules after unnamed rules' do
        resource = Puppet::Type.type(:firewall).new(name: '351 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(9)
      end
      it 'understands offsets for adding rules at the end' do
        resource = Puppet::Type.type(:firewall).new(name: '950 test')
        allow(resource.provider.class).to receive(:instances).and_return(providers)
        expect(resource.provider.insert_order).to eq(11)
      end
    end
  end

  # Load in ruby hash for test fixtures.
  load 'spec/fixtures/iptables/conversion_hash.rb'

  describe 'when converting rules to resources' do
    ARGS_TO_HASH.each do |test_name, data|
      describe "for test data '#{test_name}'" do
        let(:resource) { provider.rule_to_hash(data[:line], data[:table], 0) }

        # If this option is enabled, make sure the error was raised
        if data[:produce_warning]
          it 'the input rules should produce a warning by rules_to_hash' do
            allow(provider).to receive(:warning).with(%r{Skipping unparsable iptables rule})
            resource # force resource to get evaluated
          end
        end

        # If this option is enabled, make sure the parameters exactly match
        if data[:compare_all]
          it 'the parameter hash keys should be the same as returned by rules_to_hash' do
            expect(resource.keys).to match_array(data[:params].keys)
          end
        end

        # Iterate across each parameter, creating an example for comparison
        data[:params].each do |param_name, param_value|
          it "the parameter '#{param_name}' should match #{param_value.inspect}" do
            # booleans get cludged to string "true"
            if param_value == true
              expect(resource[param_name]).to be_truthy
            else
              expect(resource[param_name]).to eq(data[:params][param_name])
            end
          end
        end
      end
    end
  end

  describe 'when working out general_args' do
    HASH_TO_ARGS.each do |test_name, data|
      describe "for test data '#{test_name}'" do
        let(:resource) { Puppet::Type.type(:firewall).new(data[:params]) }
        let(:provider) { Puppet::Type.type(:firewall).provider(:iptables) }
        let(:instance) { provider.new(resource) }

        it 'general_args should be valid' do
          expect(instance.general_args.flatten).to eq(data[:args])
        end
      end
    end
  end

  describe 'when converting rules without comments to resources' do
    let(:sample_rule) do
      '-A INPUT -s 1.1.1.1 -d 1.1.1.1 -p tcp -m multiport --dports 7061,7062 -m multiport --sports 7061,7062 -j ACCEPT'
    end
    let(:resource) { provider.rule_to_hash(sample_rule, 'filter', 0) }
    let(:instance) { provider.new(resource) }

    it 'rule name contains a MD5 sum of the line' do
      expect(resource[:name]).to eq("9000 #{Digest::SHA256.hexdigest(resource[:line])}")
    end

    resource_types = [:chain, :source, :destination, :proto, :dport, :sport, :action]
    rule_values = ['INPUT', '1.1.1.1/32', '1.1.1.1/32', 'tcp', ['7061', '7062'], ['7061', '7062'], 'accept']
    it 'parsed the rule arguments correctly' do
      resource_types.each_with_index do |type, index|
        expect(resource[type]).to eq(rule_values[index])
      end
    end
  end

  describe 'when converting existing rules generates by system-config-firewall-tui to resources' do
    let(:sample_rule) do
      # as generated by iptables-save from rules created with system-config-firewall-tui
      '-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT'
    end
    let(:resource) { provider.rule_to_hash(sample_rule, 'filter', 0) }
    let(:instance) { provider.new(resource) }

    it 'rule name contains a MD5 sum of the line' do
      expect(resource[:name]).to eq("9000 #{Digest::SHA256.hexdigest(resource[:line])}")
    end

    resource_types = [:chain, :proto, :dport, :state, :action]
    rule_values = ['INPUT', 'tcp', ['22'], ['NEW'], 'accept']
    it 'parse arguments' do
      resource_types.each_with_index do |type, index|
        expect(resource[type]).to eq(rule_values[index])
      end
    end
  end

  describe 'when creating resources' do
    let(:instance) { provider.new(resource) }

    it 'insert_args should be an array' do
      expect(instance.insert_args.class).to eq(Array)
    end
  end

  describe 'when modifying resources' do
    let(:instance) { provider.new(resource) }

    it 'update_args should be an array' do
      expect(instance.update_args.class).to eq(Array)
    end

    it 'fails when modifying the chain' do
      expect { instance.chain = 'OUTPUT' }.to raise_error(%r{is not supported})
    end
  end

  describe 'when inverting rules' do
    let(:resource) do
      Puppet::Type.type(:firewall).new(name: '040 partial invert',
                                       table: 'filter',
                                       action: 'accept',
                                       chain: 'nova-compute-FORWARD',
                                       source: '0.0.0.0/32',
                                       destination: '255.255.255.255/32',
                                       sport: ['! 78', '79', 'talk'],
                                       dport: ['77', '! 76'],
                                       proto: 'udp')
    end
    let(:instance) { provider.new(resource) }

    it 'fails when not all array items are inverted' do
      expect { instance.insert }.to raise_error RuntimeError, %r{but '79', '517' are not prefixed}
    end
  end

  describe 'when deleting resources' do
    let(:sample_rule) do
      '-A INPUT -s 1.1.1.1 -d 1.1.1.1 -p tcp -m multiport --dports 7061,7062 -m multiport --sports 7061,7062 -j ACCEPT'
    end
    let(:resource) { provider.rule_to_hash(sample_rule, 'filter', 0) }
    let(:instance) { provider.new(resource) }

    it 'resource[:line] looks like the original rule' do
      resource[:line] == sample_rule
    end

    it 'delete_args is an array' do
      expect(instance.delete_args.class).to eq(Array)
    end

    it 'delete_args is the same as the rule string when joined' do
      expect(instance.delete_args.join(' ')).to eq(sample_rule.gsub(%r{\-A},
                                                                    '-t filter -D'))
    end
  end
end

describe 'ip6tables provider' do
  let(:provider6) { Puppet::Type.type(:firewall).provider(:ip6tables) }
  let(:resource) do
    Puppet::Type.type(:firewall).new(name: '000 test foo',
                                     action: 'accept',
                                     provider: 'ip6tables')
  end

  before :each do
    allow(Puppet::Type::Firewall).to receive(:ip6tables).and_return provider6
    allow(provider6).to receive(:command).with(:ip6tables_save).and_return '/sbin/ip6tables-save'

    # Stub iptables version
    allow(Facter.fact(:ip6tables_version)).to receive(:value).and_return '1.4.7'

    allow(Puppet::Util::Execution).to receive(:execute).and_return ''
    allow(Puppet::Util).to receive(:which).with('ip6tables-save')
                                          .and_return '/sbin/ip6tables-save'
  end

  it 'is expected to be able to get a list of existing rules' do
    provider6.instances.each do |rule|
      expect(rule).to be_instance_of(provider6)
      expect(rule.properties[:provider6].to_s).to eql provider6.name.to_s
    end
  end

  it 'is expected to ignore lines with fatal errors' do
    allow(Puppet::Util::Execution).to receive(:execute).with(['/sbin/ip6tables-save'])
                                                       .and_return('FATAL: Could not load /lib/modules/2.6.18-028stab095.1/modules.dep: No such file or directory')
    expect(provider6.instances.length).to eq 0
  end

  # Load in ruby hash for test fixtures.
  load 'spec/fixtures/ip6tables/conversion_hash.rb'

  describe 'when converting rules to resources' do
    ARGS_TO_HASH6.each do |test_name, data|
      describe "for test data '#{test_name}'" do
        let(:resource) { provider6.rule_to_hash(data[:line], data[:table], 0) }

        # If this option is enabled, make sure the parameters exactly match
        if data[:compare_all]
          it 'the parameter hash keys should be the same as returned by rules_to_hash' do
            expect(resource.keys).to match data[:params].keys
          end
        end

        # Iterate across each parameter, creating an example for comparison
        data[:params].each do |param_name, param_value|
          it "the parameter '#{param_name}' should match #{param_value.inspect}" do
            expect(resource[param_name]).to eql data[:params][param_name]
          end
        end
      end
    end
  end

  describe 'when working out general_args' do
    HASH_TO_ARGS6.each do |test_name, data|
      describe "for test data '#{test_name}'" do
        let(:resource) { Puppet::Type.type(:firewall).new(data[:params]) }
        let(:provider6) { Puppet::Type.type(:firewall).provider(:ip6tables) }
        let(:instance) { provider6.new(resource) }

        it 'general_args should be valid' do
          data[:args].unshift('--wait') if instance.general_args.flatten.include? '--wait'
          expect(instance.general_args.flatten).to eql data[:args]
        end
      end
    end
  end

  describe 'when deleting ipv6 resources' do
    let(:sample_rule) do
      '-A INPUT -i lo -m comment --comment "001 accept all to lo interface v6" -j ACCEPT'
    end

    let(:bare_sample_rule) do
      '-A INPUT -i lo -m comment --comment 001 accept all to lo interface v6 -j ACCEPT'
    end

    let(:resource) { provider6.rule_to_hash(sample_rule, 'filter', 0) }
    let(:instance) { provider6.new(resource) }

    it 'resource[:line] looks like the original rule' do
      resource[:line] == sample_rule
    end

    it 'delete_args is an array' do
      expect(instance.delete_args.class).to eq(Array)
    end
  end
end
