# frozen_string_literal: true

# require 'rails_helper'
require 'watchdog/logging/formatters/datadog'
require 'active_support/parameter_filter'
require 'JSON'
require 'active_record'

RSpec.describe Watchdog::Logging::Formatters::Datadog do
  subject(:formatter) { described_class.new }
  let(:time) { Time.utc 2019, 10, 19 }
  let(:meta) do
    {
      env:      '',
      service:  'rspec',
      source:   'ruby',
      trace_id: '0',
      version:  ''
    }
  end

  it 'formats string message' do
    log = formatter.call('INFO', time, nil, "hi")

    result   = JSON.parse(log, symbolize_names: true)
    expected = {
      status:    'INFO',
      message:   'hi',
      timestamp: '2019-10-19T00:00:00.000Z'
    }.merge(meta)

    expect(result).to eq expected
  end

  it 'formats array' do
    event = Watchdog::Event.new(
      event:      'hi',
      attributes: {
        arr: [1, 2]
      })
    log   = formatter.call('INFO', time, nil, event)

    result   = JSON.parse(log, symbolize_names: true)
    expected = {
      status:    'INFO',
      message:   'hi arr.0=1 arr.1=2',
      timestamp: '2019-10-19T00:00:00.000Z'
    }.merge(meta)

    expect(result).to eq expected
  end

  it 'formats nested array' do
    event = Watchdog::Event.new(
      event:      'hi',
      attributes: {
        arr: [1, [2, 3, [4]]]
      })
    log   = formatter.call('INFO', time, nil, event)

    result   = JSON.parse(log, symbolize_names: true)
    expected = {
      status:    'INFO',
      message:   'hi arr.0=1 arr.1.0=2 arr.1.1=3 arr.1.2.0=4',
      timestamp: '2019-10-19T00:00:00.000Z'
    }.merge(meta)

    expect(result).to eq expected
  end

  it 'formats nested' do
    event = Watchdog::Event.new(
      event:      'hi',
      attributes: {
        x: {
          foo: 'bar',
          y:   {
            z: 'z'
          }
        },
      })
    log   = formatter.call('INFO', time, nil, event)

    result   = JSON.parse(log, symbolize_names: true)
    expected = {
      status:    'INFO',
      message:   'hi x.foo=bar x.y.z=z',
      timestamp: '2019-10-19T00:00:00.000Z'
    }.merge(meta)

    expect(result).to eq expected
  end

  it 'support non symbol keys' do
    event = Watchdog::Event.new(
      event:      'hi',
      attributes: {
        1     => 0,
        'foo' => 'str'
      })
    log   = formatter.call('INFO', time, nil, event)

    result   = JSON.parse(log, symbolize_names: true)
    expected = {
      status:    'INFO',
      message:   'hi 1=0 foo=str',
      timestamp: '2019-10-19T00:00:00.000Z'
    }.merge(meta)

    expect(result).to eq expected
  end

  it 'formats all' do
    event = Watchdog::Event.new(
      event:      'hi',
      attributes: {
        1    => 0,
        x:   {
          foo: 'bar',
          y:   {
            z: 'z'
          }
        },
        arr: [1, 2],
        one: {
          two: [{ three: [{ four: { five: 5 } }] }]
        }
      })
    log   = formatter.call('INFO', time, nil, event)

    result   = JSON.parse(log, symbolize_names: true)
    expected = {
      status:    'INFO',
      message:   'hi 1=0 x.foo=bar x.y.z=z arr.0=1 arr.1=2 one.two.0.three.0.four.five=5',
      timestamp: '2019-10-19T00:00:00.000Z'
    }.merge(meta)

    expect(result).to eq expected
  end

  context 'with transformers' do
    subject(:formatter) { described_class.new(attribute_transformer: transformer) }

    let(:transformer) do
      ->(h) { h.transform_values { |v| v.to_s.upcase } }
    end

    it 'transforms' do
      event = Watchdog::Event.new(
        event:      'hi',
        attributes: {
          a: 'a',
          b: [1, { c: { d: 'd' } }]
        })
      log   = formatter.call('INFO', time, nil, event)

      result   = JSON.parse(log, symbolize_names: true)
      expected = {
        status:    'INFO',
        message:   'hi a=A b.0=1 b.1.c.d=D',
        timestamp: '2019-10-19T00:00:00.000Z'
      }.merge(meta)

      expect(result).to eq expected
    end
  end
end
