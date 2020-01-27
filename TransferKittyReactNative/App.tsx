import React from 'react';
import { SafeAreaView, StyleSheet, Text, View } from 'react-native';

import AppHeader from './components/app-header';
import History from './components/history';

import {displayName} from './app.json';

export default function App() {
  return (
      <View style={styles.container}>
        <SafeAreaView>
          <AppHeader name={displayName} style={styles.header} />
          <History />
        </SafeAreaView>
      </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'stretch',
  },
  header: {
    // width: '100%',
  },
});
