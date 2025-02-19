# frozen_string_literal: true

require 'spec_helper'

describe 'firewall::linux::debian', type: :class do
  context 'with Debian 10' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: '10.0' },
        },
      }
    end

    it {
      is_expected.to contain_package('iptables-persistent').with(
        ensure: 'installed',
      )
    }
    it {
      is_expected.to contain_service('netfilter-persistent').with(
        ensure: 'running',
        enable: 'true',
        require: 'Package[iptables-persistent]',
      )
    }
  end

  context 'with Debian 10, enable => false' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: '10' },
        },
      }
    end
    let(:params) { { enable: 'false' } }

    it {
      is_expected.to contain_service('netfilter-persistent').with(
        enable: 'false',
      )
    }
  end

  context 'with Debian 10, ensure => stopped' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: '10.0' },
        },
      }
    end
    let(:params) { { ensure: 'stopped' } }

    it {
      is_expected.to contain_service('netfilter-persistent').with(
        ensure: 'stopped',
      )
    }
  end

  context 'with Debian 11' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: '11.0' },
        },
      }
    end

    it {
      is_expected.to contain_package('iptables-persistent').with(
        ensure: 'installed',
      )
    }
    it {
      is_expected.to contain_service('netfilter-persistent').with(
        ensure: 'running',
        enable: 'true',
        require: 'Package[iptables-persistent]',
      )
    }
  end

  context 'with Debian 11, enable => false' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: '11' },
        },
      }
    end
    let(:params) { { enable: 'false' } }

    it {
      is_expected.to contain_service('netfilter-persistent').with(
        enable: 'false',
      )
    }
  end

  context 'with Debian 11, ensure => stopped' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: '10.0' },
        },
      }
    end
    let(:params) { { ensure: 'stopped' } }

    it {
      is_expected.to contain_service('netfilter-persistent').with(
        ensure: 'stopped',
      )
    }
  end

  context 'with Debian unstable' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: 'unstable' },
        },
      }
    end

    it {
      is_expected.to contain_package('netfilter-persistent').with(
        ensure: 'installed',
      )
    }
    it {
      is_expected.to contain_service('netfilter-persistent').with(
        ensure: 'running',
        enable: 'true',
        require: 'Package[netfilter-persistent]',
      )
    }
  end

  context 'with Debian unstable, enable => false' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: 'unstable' },
        },
      }
    end
    let(:params) { { enable: 'false' } }

    it {
      is_expected.to contain_service('netfilter-persistent').with(
        enable: 'false',
      )
    }
  end

  context 'with Debian unstable, ensure => stopped' do
    let(:facts) do
      {
        os: {
          family: 'Debian',
          name: 'Debian',
          release: { full: '10.0' },
        },
      }
    end
    let(:params) { { ensure: 'stopped' } }

    it {
      is_expected.to contain_service('netfilter-persistent').with(
        ensure: 'stopped',
      )
    }
  end
end
